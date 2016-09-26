/*  weightVals
 *
 * MEX function used for reducing a computational bottleneck in fillInFourierGrid_C.m
 *
 * Author: AJ Pryor
 * Jianwei (John) Miao Coherent Imaging Group
 * University of California, Los Angeles
 * Copyright (c) 2015. All Rights Reserved.
 * 
 */

#include <vector>
#include <iostream>
#include "mex.h"
#include <iomanip>
#include <complex>
#include <cmath>
#include <math.h>
using namespace std;

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{  // initialize variables/pointers
	double *multiInd;
	double *masterDistances, *masterValuesReal, *masterValuesComplex,*uniqueInd,*masterConfidenceWeights;
	mxArray *MI, *MD, *MVR, *UI;
    const double PI = 3.14159265358979323846;
	//get pointers to input objects and fetch dimensions
	 multiInd = mxGetPr(prhs[0]);
	 masterDistances = mxGetPr(prhs[1]);
	 masterValuesReal = mxGetPr(prhs[2]);
	 masterValuesComplex = mxGetPi(prhs[2]);
	 uniqueInd = mxGetPr(prhs[3]);
     masterConfidenceWeights = mxGetPr(prhs[4]);
    int numInd, dimy, numdims;
	const mwSize *dims;
	dims = mxGetDimensions(prhs[0]);
	dimy = (long int)dims[0];
	numInd = (long int)dims[1];
    
	//initialize outputs
	plhs[0] = mxCreateDoubleMatrix(dimy, numInd, mxREAL);
	plhs[1] = mxCreateDoubleMatrix(dimy, numInd, mxREAL);
	plhs[2] = mxCreateDoubleMatrix(dimy, numInd, mxREAL);
	plhs[3] = mxCreateDoubleMatrix(dimy, numInd, mxREAL);
    plhs[4] = mxCreateDoubleMatrix(dimy, numInd, mxREAL);
    plhs[5] = mxCreateDoubleMatrix(dimy, numInd, mxREAL);

	//separate real and complex parts and recombine later
	double *magnitudesOut, *valuesOutReal, *valuesOutComplex,*weightedConfidenceWeights,*weightedDistances,*sigmaPhases;
    magnitudesOut = mxGetPr(plhs[0]);
	valuesOutReal = mxGetPr(plhs[1]);
	valuesOutComplex = mxGetPr(plhs[2]);
    weightedConfidenceWeights = mxGetPr(plhs[3]);
    weightedDistances = mxGetPr(plhs[4]);
    sigmaPhases = mxGetPr(plhs[5]);
    
    //initialize vectors that will be used to hold the values for each grid point
	vector<double> tmpValuesReal;
	vector<double> tmpValuesComplex;
	vector<double> tmpWeights;
    vector<double> tmpConfidenceWeights;
    vector<double> tmpDistances;
    vector<double> tmpPhases1;
    vector<double> tmpPhases2;
    vector<double> phaseResiduals;
    
//     double phaseErrorSigmaTolerance2 = 15*PI/180;
    long int kkk = 0;
	// loop over each voxel that was repeatedly matched
	for (long int i = 0; i <= (numInd - 2); i++){
		double ind1 = uniqueInd[(long int)multiInd[i] - 1]-1;
		double ind2 = uniqueInd[(long int)multiInd[i]]-2;
		long int lengthOfVector = (long int)ind2 - (long int)ind1 + 1;
		// resize vectors
		tmpValuesReal.resize(lengthOfVector);
		tmpValuesComplex.resize(lengthOfVector);
		tmpWeights.resize(lengthOfVector);
        tmpConfidenceWeights.resize(lengthOfVector);
        tmpDistances.resize(lengthOfVector);
        tmpPhases1.resize(lengthOfVector);
        tmpPhases2.resize(lengthOfVector);
        phaseResiduals.resize(lengthOfVector);
		double distanceSum= 0;

		// compute sum of inverse distances for normalization
        for (long int j = 0; j <= lengthOfVector-1; j++){
			tmpValuesReal[j] = masterValuesReal[(long int)ind1 + j];
			tmpValuesComplex[j] = masterValuesComplex[(long int)ind1 + j];
            tmpDistances[j] = masterDistances[(long int)ind1 + j] + 1e-30;
            distanceSum = distanceSum + (masterConfidenceWeights[(long int)ind1 + j] + 1e-30)  / (masterDistances[(long int)ind1 + j] + 1e-30);
            tmpConfidenceWeights[j] = masterConfidenceWeights[(long int)ind1 + j];
		}
		valuesOutReal[i] = 0; 
		magnitudesOut[i] = 0;
		valuesOutComplex[i] = 0;
       for (long int j = 0; j <= lengthOfVector-1; j++){
            tmpWeights[j] = tmpConfidenceWeights[j] / (masterDistances[(long int)ind1 + j] + 1e-30) / distanceSum;//current weight
			valuesOutReal[i] = valuesOutReal[i] + tmpWeights[j] * tmpValuesReal[j];//weighted value for real and complex part is used for phase of final value
			valuesOutComplex[i] = valuesOutComplex[i] + tmpWeights[j] * tmpValuesComplex[j];
			magnitudesOut[i] = magnitudesOut[i] + tmpWeights[j] * sqrt(tmpValuesReal[j] * tmpValuesReal[j] + tmpValuesComplex[j] * tmpValuesComplex[j]);//weighted magnitude will be final magnitude
            weightedConfidenceWeights[i] = weightedConfidenceWeights[i] + tmpWeights[j] * tmpConfidenceWeights[j];
            weightedDistances[i] = weightedDistances[i] + tmpWeights[j] * tmpDistances[j];
       }
        double weightedPhase,residual1,residual2,sigmaPhaseSum,weightSum,sigmaPhase,factor;
                weightedPhase = atan2(valuesOutComplex[i],valuesOutReal[i]);
                sigmaPhase = 0;
                weightSum = 0;
                sigmaPhaseSum = 0;
        for (int j = 0; j <= lengthOfVector-1; j++){
        
            tmpPhases1[j] = atan2(tmpValuesComplex[j],tmpValuesReal[j]);

            if (tmpPhases1[j] > weightedPhase){
                    factor = -2*PI;
            }
            else {
                    factor = 2*PI;
                    
            }
            residual1 = abs(tmpPhases1[j]-weightedPhase);
            residual2 = abs(tmpPhases1[j]+factor-weightedPhase);
            phaseResiduals[j] = (residual1<residual2)?residual1:residual2;
            sigmaPhaseSum += tmpWeights[j]*phaseResiduals[j]*phaseResiduals[j];
            weightSum = weightSum + tmpWeights[j];

        }
                sigmaPhase = sqrt(sigmaPhaseSum/(weightSum+1e-30));
                sigmaPhases[i] = sigmaPhase;

    }

		return;
}

