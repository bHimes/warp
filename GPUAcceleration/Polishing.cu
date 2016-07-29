#include "Functions.h"
#include <device_functions.h>
using namespace gtom;

#define SHIFT_THREADS 128

__global__ void PolishingGetDiffKernel(float2* d_phase, float2* d_average, float2* d_shiftfactors, float2* d_ctfcoords, CTFParamsLean* d_ctfparams, float* d_invsigma, uint length, float2* d_shifts, float* d_diff, float* d_debugdiff);


__declspec(dllexport) void CreatePolishing(float* d_particles, float2* d_particlesft, float* d_masks, int2 dims, int2 dimscropped, int nparticles, int nframes)
{
	float* d_temp;
	cudaMalloc((void**)&d_temp, ElementsFFT2(dims) * nparticles * sizeof(float2));

	for(int z = 0; z < nframes / 3; z++)
	{
		cudaMemcpy(d_temp, d_particles + Elements2(dims) * nparticles * (z * 3 + 0), Elements2(dims) * nparticles * sizeof(float), cudaMemcpyDeviceToDevice);
		d_AddVector(d_temp, d_particles + Elements2(dims) * nparticles * (z * 3 + 1), d_temp, Elements2(dims) * nparticles);
		d_AddVector(d_temp, d_particles + Elements2(dims) * nparticles * (z * 3 + 2), d_temp, Elements2(dims) * nparticles);

		//d_NormMonolithic(d_temp, d_temp, Elements2(dims), d_masks, T_NORM_MEAN01STD, nparticles);
	    //d_MultiplyByVector(d_temp, d_masks, d_temp, Elements2(dims) * nparticles);
		float radius = 90.0f / (1.0605f / 1.25f);
		d_SphereMask(d_temp, d_temp, toInt3(dims), &radius, 24, NULL, nparticles);
		d_RemapFull2FullFFT(d_temp, d_temp, toInt3(dims), nparticles);
		d_FFTR2C(d_temp, (float2*)d_temp, 2, toInt3(dims), nparticles);
		d_FFTCrop((float2*)d_temp, d_particlesft + ElementsFFT2(dimscropped) * nparticles * z, toInt3(dims), toInt3(dimscropped), nparticles);
	}

	cudaFree(d_temp);
}

__declspec(dllexport) void PolishingGetDiff(float2* d_phase, 
												float2* d_average, 
												float2* d_shiftfactors, 
												float2* d_ctfcoords,
												CTFParams* h_ctfparams,
												float* d_invsigma,
												int2 dims, 
												float2* d_shifts,
												float* h_diff, 
												float* h_diffall,
												uint npositions, 
												uint nframes)
{
	int TpB = SHIFT_THREADS;
	dim3 grid = dim3(1, npositions, nframes);

	float* d_diff;
	cudaMalloc((void**)&d_diff, npositions * nframes * grid.x * sizeof(float));
	float* d_diffreduced;
	cudaMalloc((void**)&d_diffreduced, npositions * nframes * sizeof(float));

	CTFParamsLean* h_lean = (CTFParamsLean*)malloc(npositions * nframes * sizeof(CTFParamsLean));
	for (int i = 0; i < npositions * nframes; i++)
		h_lean[i] = CTFParamsLean(h_ctfparams[i], toInt3(dims));
	CTFParamsLean* d_lean = (CTFParamsLean*)CudaMallocFromHostArray(h_lean, npositions * nframes * sizeof(CTFParamsLean));
	free(h_lean);

	float* d_debugdiff = NULL;
	//cudaMalloc((void**)&d_debugdiff, npositions * nframes * ElementsFFT2(dims) * sizeof(float));

	PolishingGetDiffKernel <<<grid, TpB>>> (d_phase, d_average, d_shiftfactors, d_ctfcoords, d_lean, d_invsigma, ElementsFFT2(dims), d_shifts, d_diff, d_debugdiff);

	//d_WriteMRC(d_debugdiff, toInt3(dims.x / 2 + 1, dims.y, npositions * nframes), "d_debugdiff.mrc");

	//d_SumMonolithic(d_diff, d_diffreduced, grid.x, npositions * nframes);
	d_ReduceMean(d_diff, d_diffreduced, npositions, nframes);
	cudaMemcpy(h_diff, d_diffreduced, npositions * sizeof(float), cudaMemcpyDeviceToHost);

	cudaMemcpy(h_diffall, d_diff, npositions * nframes * sizeof(float), cudaMemcpyDeviceToHost);
	
	cudaFree(d_lean);
	cudaFree(d_diffreduced);
	cudaFree(d_diff);
}

/*__global__ void PolishingGetDiffKernel(float2* d_phase, float2* d_average, float2* d_shiftfactors, float2* d_ctfcoords, CTFParamsLean* d_ctfparams, float* d_invsigma, uint length, float2* d_shifts, float* d_diff, float* d_debugdiff)
{
	__shared__ float s_diff[SHIFT_THREADS];
	s_diff[threadIdx.x] = 0.0f;

	uint specid = blockIdx.z * gridDim.y + blockIdx.y;
	d_phase += specid * length;
	d_average += specid * length;
	d_debugdiff += specid * length;

	float2 shift = d_shifts[specid];
	float diffsum = 0.0f;

	CTFParamsLean ctfparams = d_ctfparams[specid];

	for (uint id = threadIdx.x; 
		 id < length; 
		 id += SHIFT_THREADS)
	{
		float2 value = d_phase[id];
		float2 average = d_average[id];
		float ctf = d_GetCTF<false>(d_ctfcoords[id].x, d_ctfcoords[id].y, ctfparams);	// Already corrected for mag anisotropy.
		average *= ctf;

		float2 shiftfactors = d_shiftfactors[id];

		float phase = shiftfactors.x * shift.x + shiftfactors.y * shift.y;
		float2 change = make_float2(__cosf(phase), __sinf(phase));
		value = cuCmulf(value, change);

		float2 diff = value - average;

		diffsum += (diff.x * diff.x + diff.y * diff.y) * d_invsigma[id];
		//d_debugdiff[id] = shift.x;
	}

	s_diff[threadIdx.x] = diffsum;
	__syncthreads();

	for (uint lim = 64; lim > 1; lim >>= 1)
	{
		if (threadIdx.x < lim)
		{
			diffsum += s_diff[threadIdx.x + lim];
			s_diff[threadIdx.x] = diffsum;
		}
		__syncthreads();
	}

	if (threadIdx.x == 0)
	{
		diffsum += s_diff[1];

		d_diff[specid] = diffsum / (float)length;
	}
}*/

__global__ void PolishingGetDiffKernel(float2* d_phase, float2* d_average, float2* d_shiftfactors, float2* d_ctfcoords, CTFParamsLean* d_ctfparams, float* d_invsigma, uint length, float2* d_shifts, float* d_diff, float* d_debugdiff)
{
	__shared__ float s_num[SHIFT_THREADS];
	s_num[threadIdx.x] = 0.0f;
	__shared__ float s_denom1[SHIFT_THREADS];
	s_denom1[threadIdx.x] = 0.0f;
	__shared__ float s_denom2[SHIFT_THREADS];
	s_denom2[threadIdx.x] = 0.0f;

	uint specid = blockIdx.z * gridDim.y + blockIdx.y;
	d_phase += specid * length;
	d_average += specid * length;
	d_debugdiff += specid * length;

	float2 shift = d_shifts[specid];
	float numsum = 0.0f, denomsum1 = 0.0f, denomsum2 = 0.0f;

	CTFParamsLean ctfparams = d_ctfparams[specid];

	for (uint id = threadIdx.x; 
		 id < length; 
		 id += SHIFT_THREADS)
	{
		float2 value = d_phase[id];
		float2 average = d_average[id];
		float ctf = d_GetCTF<false>(d_ctfcoords[id].x, d_ctfcoords[id].y, ctfparams);	// Already corrected for mag anisotropy.
		average *= ctf;

		float2 shiftfactors = d_shiftfactors[id];

		float phase = shiftfactors.x * shift.x + shiftfactors.y * shift.y;
		float2 change = make_float2(__cosf(phase), __sinf(phase));
		value = cuCmulf(value, change);

		float invsigma = d_invsigma[id];
		value *= invsigma;
		average *= invsigma;

		numsum += value.x * average.x + value.y * average.y;
		denomsum1 += dotp2(value, value);
		denomsum2 += dotp2(average, average);
	}
	
	s_num[threadIdx.x] = numsum;
	s_denom1[threadIdx.x] = denomsum1;
	s_denom2[threadIdx.x] = denomsum2;
	__syncthreads();

	for (uint lim = 64; lim > 1; lim >>= 1)
	{
		if (threadIdx.x < lim)
		{
			numsum += s_num[threadIdx.x + lim];
			s_num[threadIdx.x] = numsum;
			
			denomsum1 += s_denom1[threadIdx.x + lim];
			s_denom1[threadIdx.x] = denomsum1;
			
			denomsum2 += s_denom2[threadIdx.x + lim];
			s_denom2[threadIdx.x] = denomsum2;
		}
		__syncthreads();
	}

	if (threadIdx.x == 0)
	{
		numsum += s_num[1];
		denomsum1 += s_denom1[1];
		denomsum2 += s_denom2[1];

		d_diff[specid * gridDim.x] = numsum / tmax(1e-6f, sqrt(denomsum1 * denomsum2));
	}
}