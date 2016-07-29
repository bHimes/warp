#include "Functions.h"

__declspec(dllexport) int __stdcall GetDeviceCount()
{
	int result = 0;
	cudaGetDeviceCount(&result);

	return result;
}

__declspec(dllexport) void __stdcall SetDevice(int device)
{
	cudaSetDevice(device);
}

__declspec(dllexport) int __stdcall GetDevice()
{
    int device = 0;
    cudaGetDevice(&device);

    return device;
}

__declspec(dllexport) long __stdcall GetFreeMemory(int device)
{
    int currentdevice = 0;
    cudaGetDevice(&currentdevice);

    cudaSetDevice(device);

	size_t freemem = 0, totalmem = 0;
	cudaMemGetInfo(&freemem, &totalmem);

    cudaSetDevice(currentdevice);

	return (long)(freemem >> 20);
}

__declspec(dllexport) long __stdcall GetTotalMemory(int device)
{
    int currentdevice = 0;
    cudaGetDevice(&currentdevice);

    cudaSetDevice(device);

    size_t freemem = 0, totalmem = 0;
    cudaMemGetInfo(&freemem, &totalmem);

    cudaSetDevice(currentdevice);

    return (long)(totalmem >> 20);
}