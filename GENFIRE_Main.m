%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                                                                         %%
%%                        Welcome to GENFIRE!                              %%
%%           GENeralized Fourier Iterative REconstruction                  %%
%%                                                                         %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Author: Alan (AJ) Pryor, Jr.
%% email:  apryor6@gmail.com
%% Jianwei (John) Miao Coherent Imaging Group
%% University of California, Los Angeles
%% Copyright (c) 2015. All Rights Reserved.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



addpath ./source/
addpath ./data/
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%                          User Parameters                              %%% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% See the README for description of parameters
% 
% filename_Projections = './data/projections.mat';
% filename_Angles = './data/angles.mat';

filename_Projections = '../pjs2.mat';
filename_Angles = '../angle2.mat';
% filename_Support = './data/support180.mat'; 
filename_Support = './data/support.mat'; 
% filename_Support = './data/support180_180_90.mat'; 
% filename_Support = './data/support180_180_168.mat'; 

% filename_InitialModel = '';
% filename_Results = './results/GENFIRE_rec180_gridOS25.mat';
filename_Results = '../GENFIRE_rec2.mat';
numIterations = 50; 
pixelSize = .5; 
oversamplingRatio =3;
griddingMethod = 1; 
allowMultipleGridMatches = 0;
constraintEnforcementMode = 1; 
% interpolationCutoffDistance =.7; interpolationCutoffDistance =.7; 
% interpolationCutoffDistance =.7; 
interpolationCutoffDistance =.5;
% interpolationCutoffDistance =.005; 
constraintPositivity = 1;
constraintSupport = 1;
ComputeFourierShellCorrelation = 0; 
numBins = 50;
percentValuesForRfree = 0.05;
numBinsRfree = 35;
doCTFcorrection = 0;
CTFThrowOutThreshhold = 0;

useCustomGridSize = 0;
FourierGridSize = [180 180 90]; % manually input desired Fourier grid size or set to [] to automatically determine

useCustomEulerConvention = 1;
Euler_rot_vecs = {[0; 0; 1],[0; 1; 0],[0; 0; 1]};




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Begin GENFIRE

%construct the flags for resolution extension control
switch constraintEnforcementMode
    case 1
        constraintEnforcementDelayIndicators = [0.95:-0.1:-0.15 -10 -10 -10 -0.15:0.1:.95];  
    case 2
        constraintEnforcementDelayIndicators = [0.95:-0.1:-0.15 -10 -10];
    case 3
        constraintEnforcementDelayIndicators = [-999, -999, -999, -999, -999];
    otherwise
        error('GENFIRE: ERROR! constraintEnforcementMode value %d not understood',constraintEnforcementMode)
end

%create reconstruction parameter structure, this is much easier than
%passing a ton of parameters
GENFIRE_parameters.filename_Projections = filename_Projections;
GENFIRE_parameters.filename_Angles = filename_Angles;
GENFIRE_parameters.filename_Support = filename_Support;
GENFIRE_parameters.filename_Results = filename_Results;
if exist('filename_InitialModel','var')
    GENFIRE_parameters.filename_InitialModel = filename_InitialModel;
else
    GENFIRE_parameters.filename_InitialModel = [];
end
GENFIRE_parameters.numIterations = numIterations;
GENFIRE_parameters.pixelSize = pixelSize;
GENFIRE_parameters.oversamplingRatio = oversamplingRatio;
GENFIRE_parameters.interpolationCutoffDistance = interpolationCutoffDistance;
GENFIRE_parameters.constraintPositivity = constraintPositivity;
GENFIRE_parameters.constraintSupport = constraintSupport;
if useCustomGridSize == 1
    GENFIRE_parameters.userSetGridSize = true;
    GENFIRE_parameters.FourierGridSize   = FourierGridSize;
else
    GENFIRE_parameters.userSetGridSize = false;
    GENFIRE_parameters.FourierGridSize   = [];
end

if useCustomEulerConvention == 1
    GENFIRE_parameters.Euler_rot_vecs = Euler_rot_vecs;
else
    GENFIRE_parameters.Euler_rot_vecs = {[0; 0; 1],[0; 1; 0],[0; 0; 1]};
end
GENFIRE_parameters.useCustomEulerConvention = useCustomEulerConvention;

if exist('particleWindowSize','var')
    GENFIRE_parameters.particleWindowSize = particleWindowSize;
else
    GENFIRE_parameters.particleWindowSize = [];
end
GENFIRE_parameters.numBins = numBins;
GENFIRE_parameters.percentValuesForRfree = percentValuesForRfree;
GENFIRE_parameters.numBinsRfree = numBinsRfree;
GENFIRE_parameters.doCTFcorrection = doCTFcorrection;
GENFIRE_parameters.CTFThrowOutThreshhold = CTFThrowOutThreshhold;
GENFIRE_parameters.griddingMethod = griddingMethod;
GENFIRE_parameters.allowMultipleGridMatches = allowMultipleGridMatches;
if exist('phaseErrorSigmaTolerance','var')
    GENFIRE_parameters.phaseErrorSigmaTolerance = phaseErrorSigmaTolerance;
else
    GENFIRE_parameters.phaseErrorSigmaTolerance = [];
end
GENFIRE_parameters.constraintEnforcementDelayIndicators = constraintEnforcementDelayIndicators;


if ComputeFourierShellCorrelation
    %If this is turned on, the data will be split in half, independently
    %reconstructed, and the FSC will be calculated between the two halves
    %as a cross validation metric. This is often used to determine
    %resolution. This process creates intermediate files in ./scratch/ that
    %will be deleted once it's finished. You can comment out the delete
    %statements if you need to save the intermediate half reconstruction
    %results
    fprintf('GENFIRE: Dividing datasets in half for FSC calculation...\n\n')
    projections = single(importdata(GENFIRE_parameters.filename_Projections));
    angles = single(importdata(GENFIRE_parameters.filename_Angles));
    if size(angles,2)>3
        error('The dimension of the angles is incorrect.\n\n')
    end
    if size(angles,2) ==1 
        angles = [zeros(1,length(angles));angles;zeros(1,length(angles))]';%tomography tilt is the theta angle
    end
    %make sure the size of the projections is sufficient to divide in half
    if size(projections,3) < 2
       error('GENFIRE: ERROR! Too few projections to calculate FSC\n\n') 
    end
    
    %divide dataset in half
    pj1 = projections(:,:,1:2:end);
    pj2 = projections(:,:,2:2:end);
    angles1 = angles(1:2:end,:);
    angles2 = angles(2:2:end,:);
    
    if ~isdir('scratch')
        mkdir scratch
    end
    %save projections (temporarily)
    save('scratch/projections_half_1.mat','pj1')
    save('scratch/projections_half_2.mat','pj2')
    save('scratch/angles_half_1.mat','angles1')
    save('scratch/angles_half_2.mat','angles2')
    
    GENFIRE_parameters_half1 = GENFIRE_parameters;
    GENFIRE_parameters_half2 = GENFIRE_parameters;
    GENFIRE_parameters_half1.filename_Projections = 'scratch/projections_half_1.mat';
    GENFIRE_parameters_half2.filename_Projections = 'scratch/projections_half_2.mat';
    GENFIRE_parameters_half1.filename_Angles = 'scratch/angles_half_1.mat';
    GENFIRE_parameters_half2.filename_Angles = 'scratch/angles_half_2.mat';
    GENFIRE_parameters_half1.filename_Results = 'scratch/results_half_1.mat';
    GENFIRE_parameters_half2.filename_Results = 'scratch/results_half_2.mat';
    %reconstruct halves individually
    fprintf('GENFIRE: Reconstructing first half...\n\n')
    GENFIRE_reconstruct(GENFIRE_parameters_half1)
    fprintf('GENFIRE: Reconstructing second half...\n\n')
    GENFIRE_reconstruct(GENFIRE_parameters_half2)
    GENFIRE_parameters_half1 = importdata('scratch/results_half_1.mat');
    GENFIRE_parameters_half2 = importdata('scratch/results_half_2.mat');
    fprintf('GENFIRE: Independent reconstructions complete. Calculating FSC.\n\n')
    [FSC, spatialFrequency] = FourierShellCorrelate(GENFIRE_parameters_half1.reconstruction, GENFIRE_parameters_half2.reconstruction,numBins,pixelSize);
    figure, plot(spatialFrequency,FSC,'k','LineWidth',3)
    set(gcf,'color','white')
    title('FSC between independent half reconstructions','FontSize',16)
    xlabel('Spatial Frequency','FontSize',14)
    ylabel('Correlation Coefficient','FontSize',14)
    
    %delete temporary files
    delete('scratch/projections_half*.mat','scratch/angles_half*.mat', 'scratch/results_half*.mat')
    rmdir scratch
end
    
%run reconstruction
GENFIRE_reconstruct(GENFIRE_parameters)


