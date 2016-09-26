%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                                                                         %%
%%                        Welcome to GENFIRE!                              %%
%%           GENeralized Fourier Iterative REconstruction                  %%
%%                                                                         %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% GENFIRE is a robust, Fourier-based reconstruction algorithm that is
%% capable of using a limited set of input projections to generate a 3D reconstruction
%% while also partially retrieving missing projection information. It does this by iterating 
%% between real and reciprocal space and applying simple constraints in each to find an optimal solution that  
%% correlates with the input projections while simultaneously obeying real space conditions
%% such as positivity (the assumption that there is no negative electron density)
%% and support (we require that the 3D object resulting from zero padded projections
%% exists entirely within some smaller region). The result is a more consistent 
%% and faithful reconstruction with superior contrast and, in many cases, resolution when
%% compared with more traditional 3D reconstruction algorithms such as
%% Filtered Back-Projection.  

%% Author: AJ Pryor
%% Jianwei (John) Miao Coherent Imaging Group
%% University of California, Los Angeles
%% Copyright (c) 2015. All Rights Reserved.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function GENFIRE_Main_Tomo_subsection(projectionBottom,projectionTopIncrement)
addpath ./source/
addpath ./data/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%   User Parameters   %%%
filename_Projections = 'projections_tomo.mat';%%filename of projections, which should be size NxNxN_projections where N_projections is the number of projections

filename_Angles = 'angles_tomo.mat';%%angles can be either a 1xN_projections array containing a single tilt series, or

%%a 3xN_projections array containing 3 Euler angles for each projections in the form [phi;theta;psi]
filename_Support = 'support60.mat'; %% NxNxN binary array specifying a region of 1's in which the reconstruction can exist 

% filename_InitialModel = '.\models\betagal\model.mat';

filename_Results = 'GENFIRE_rec.mat';


global numIterations 
numIterations =25; 

global pixelSize
pixelSize = .5; 

oversamplingRatioX =3; %%The code will zero-pad projections for you to the inputted oversampling ratio. If your projections are already oversampled
%%then set this to 1.

oversamplingRatioY =1.0; %%The code will zero-pad projections for you to the inputted oversampling ratio. If your projections are already oversampled
%%then set this to 1.

griddingMethod = 1; %% 1) Use fastest FFT method with mex-compiled function weightVals.cpp (see INSTALL_NOTES.txt for more info). 2) Use FFT method. 3) Use DFT method, which exactly calculates the closest measured value to each grid point rather than using the nearest FFT pixel. This is the most accurate but also slowest method

interpolationCutoffDistance =.7; %%radius of sphere (in pixels) within which to include measured datapoints 
%%when assembling the 3D Fourier grid

% particleWindowSize = 58; %size of window to crop out of projections (before oversampling). Comment out to just use the size of the input projections This is especially useful if you are doing CTF correction, as the CTF correction
%% is more accurate on larger arrays, but the portion of the micrograph containing your particle may be smaller than the input images. This allows you to CTF correct
%% the larger projections, then crop a window out and pad that with zeros for reconstruction.

ComputeFourierShellCorrelation = 1; %%set to 1 to divide dataset in half, independently reconstruct, and compute Fourier Shell Correlation (FSC) between two halves.

numBins = 50; %number of bins for FRC averaging
%% If you do not need FRC, set ComputeFourierShellCorrelation to 0 for speed as the FRC calculation requires reconstructing everything twice

constraintEnforcementMode = 1; % 1) Use resoution extension/suppression. 2) Resolution extension only 3) Enforce all datapoints always.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%     Parameters that are unlikely to need to changing        %%%
percentValuesForRfree = 0.05;
numBinsRfree = 10;
% phaseErrorSigmaTolerance = 75*pi/180;%the standard deviation of the phases of the constituent datapoints is calculated for each Fourier grid point. If this standard deviation is above this tolerance threshhold, that grid point is ignored, as the phase is uncertain. This generally happens at the boundary of speckles, where the phase changes abruptly.
doCTFcorrection = 0;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch constraintEnforcementMode
    case 1
        constraintEnforcementDelayWeights = [0.95:-0.1:-0.15, -0.15:0.1:.95];  
    case 2
        constraintEnforcementDelayWeights = [0.95:-0.1:-0.15];
    case 3
        constraintEnforcementDelayWeights = [-999, -999, -999, -999, -999];
    otherwise
        error('GENFIRE: ERROR! constraintEnforcementMode value %d not understood',constraintEnforcementMode)
end

%create parameter structure
GENFIRE_parameters.filename_Projections = filename_Projections;
GENFIRE_parameters.filename_Angles = filename_Angles;
GENFIRE_parameters.filename_Support = filename_Support;
GENFIRE_parameters.filename_Results = [filename_Results '_start' num2str(projectionBottom)];
if exist('filename_InitialModel','var')
    GENFIRE_parameters.filename_InitialModel = filename_InitialModel;
else
    GENFIRE_parameters.filename_InitialModel = [];
end
GENFIRE_parameters.numIterations = numIterations;
GENFIRE_parameters.pixelSize = pixelSize;
GENFIRE_parameters.oversamplingRatioX = oversamplingRatioX;
GENFIRE_parameters.oversamplingRatioY = oversamplingRatioY;
GENFIRE_parameters.interpolationCutoffDistance = interpolationCutoffDistance;
if exist('particleWindowSize','var')
GENFIRE_parameters.particleWindowSize = particleWindowSize;
else
    GENFIRE_parameters.particleWindowSize = [];
end
GENFIRE_parameters.numBins = numBins;
GENFIRE_parameters.percentValuesForRfree = percentValuesForRfree;
GENFIRE_parameters.numBinsRfree = numBinsRfree;
GENFIRE_parameters.doCTFcorrection = doCTFcorrection;
GENFIRE_parameters.griddingMethod = griddingMethod;
if exist('phaseErrorSigmaTolerance','var')
    GENFIRE_parameters.phaseErrorSigmaTolerance = phaseErrorSigmaTolerance;
else
    GENFIRE_parameters.phaseErrorSigmaTolerance = [];
end
GENFIRE_parameters.constraintEnforcementDelayWeights = constraintEnforcementDelayWeights;
GENFIRE_parameters.projectionBottom = projectionBottom;
GENFIRE_parameters.projectionTopIncrement = projectionTopIncrement;

if ComputeFourierShellCorrelation
    fprintf('GENFIRE: Dividing datasets in half for FSC calculation...\n\n')
    projections = single(importdata(GENFIRE_parameters.filename_Projections));
    angles = single(importdata(GENFIRE_parameters.filename_Angles));
    if size(angles,1)>3
        error('The dimension of the angles is incorrect.\n\n')
    end
    if size(angles,1) ==1 
        angles = [zeros(1,length(angles));angles;zeros(1,length(angles))];%tomography tilt is the theta angle
    end
    %make sure the size of the projections is sufficient to divide in half
    if size(projections,3) < 2
       error('GENFIRE: ERROR! Too few projections to calculate FSC\n\n') 
    end
    
    %divide dataset in half
    pj1 = projections(:,:,1:2:end);
    pj2 = projections(:,:,2:2:end);
    angles1 = angles(:,1:2:end);
    angles2 = angles(:,2:2:end);

    %save projections (temporarily)
    save(['projections_half_1' '_start' num2str(projectionBottom) '.mat'],'pj1')
    save(['projections_half_2' '_start' num2str(projectionBottom) '.mat'],'pj2')
    save('angles_half_1.mat','angles1')
    save('angles_half_2.mat','angles2')
    
    GENFIRE_parameters_half1 = GENFIRE_parameters;
    GENFIRE_parameters_half2 = GENFIRE_parameters;
    GENFIRE_parameters_half1.filename_Projections = ['projections_half_1' '_start' num2str(projectionBottom) '.mat'];
    GENFIRE_parameters_half2.filename_Projections = ['projections_half_2' '_start' num2str(projectionBottom) '.mat'];
    GENFIRE_parameters_half1.filename_Angles = 'angles_half_1.mat';
    GENFIRE_parameters_half2.filename_Angles = 'angles_half_2.mat';
    GENFIRE_parameters_half1.filename_Results = ['results_half_1.mat' '_start' num2str(projectionBottom) '.mat'];
    GENFIRE_parameters_half2.filename_Results = ['results_half_2.mat' '_start' num2str(projectionBottom) '.mat'];
    %reconstruct halves individually
    fprintf('GENFIRE: Reconstructing first half...\n\n')
    GENFIRE_reconstruct_subsection(GENFIRE_parameters_half1)
    fprintf('GENFIRE: Reconstructing second half...\n\n')
    GENFIRE_reconstruct_subsection(GENFIRE_parameters_half2)
    GENFIRE_parameters_half1 = importdata(GENFIRE_parameters_half1.filename_Results);
    GENFIRE_parameters_half2 = importdata(GENFIRE_parameters_half2.filename_Results);
    fprintf('GENFIRE: Independent reconstructions complete. Calculating FSC.\n\n')
    [FSC, spatialFrequency] = FourierShellCorrelate(GENFIRE_parameters_half1.reconstruction, GENFIRE_parameters_half2.reconstruction,numBins,pixelSize);
    figure, plot(spatialFrequency,FSC)
    title('FSC between independent half reconstructions','FontSize',16)
    xlabel('Spatial Frequency','FontSize',14)
    ylabel('Correlation Coefficient','FontSize',14)
    
    %delete temporary files
    delete('projections_half_1.mat','projections_half_2.mat','angles_half_1.mat','angles_half_2.mat')
end
    
%run reconstruction
GENFIRE_reconstruct_subsection(GENFIRE_parameters)


