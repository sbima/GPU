/*
 *
 */

// Utilities and system includes
#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <matrixMul_kernel.cu>

    //Heloper Function
    // This will output the proper CUDA error strings in the event that a CUDA host call returns an error
    #define checkCudaErrors(err)           __checkCudaErrors (err, __FILE__, __LINE__)

    inline void __checkCudaErrors( cudaError err, const char *file, const int line )
    {
        if( cudaSuccess != err) {
		    fprintf(stderr, "%s(%i) : CUDA Runtime API error %d: %s.\n",
                    file, line, (int)err, cudaGetErrorString( err ) );
            exit(-1);
        }
    }

    // This will output the proper error string when calling cudaGetLastError
    #define getLastCudaError(msg)      __getLastCudaError (msg, __FILE__, __LINE__)
    inline void __getLastCudaError( const char *errorMessage, const char *file, const int line )
    {
        cudaError_t err = cudaGetLastError();
        if( cudaSuccess != err) {
            fprintf(stderr, "%s(%i) : getLastCudaError() CUDA error : %s : (%d) %s.\n",
                    file, line, errorMessage, (int)err, cudaGetErrorString( err ) );
            exit(-1);
        }
    }
    // General GPU Device CUDA Initialization
    int gpuDeviceInit(int devID)
    {
        int deviceCount;
        checkCudaErrors(cudaGetDeviceCount(&deviceCount));
        if (deviceCount == 0) {
            fprintf(stderr, "gpuDeviceInit() CUDA error: no devices supporting CUDA.\n");
            exit(-1);
        }
        if (devID < 0) 
            devID = 0;
        if (devID > deviceCount-1) {
            fprintf(stderr, "\n");
            fprintf(stderr, ">> %d CUDA capable GPU device(s) detected. <<\n", deviceCount);
            fprintf(stderr, ">> gpuDeviceInit (-device=%d) is not a valid GPU device. <<\n", devID);
            fprintf(stderr, "\n");
            return -devID;
        }

        cudaDeviceProp deviceProp;
        checkCudaErrors( cudaGetDeviceProperties(&deviceProp, devID) );
        if (deviceProp.major < 1) {
            fprintf(stderr, "gpuDeviceInit(): GPU device does not support CUDA.\n");
            exit(-1);                                                  \
        }

        checkCudaErrors( cudaSetDevice(devID) );
        //printf("> gpuDeviceInit() CUDA device [%d]: %s\n", devID, deviceProp.name);
        return devID;
    }

// end of CUDA Helper Functions

////////////////////////////////////////////////////////////////////////////////
// declaration, forward
void doMatrixMul(int argc, char** argv);
void randomInit(float*, int);


void inline checkError(cublasStatus_t status, const char* msg)
{
    if(status != CUBLAS_STATUS_SUCCESS){
        printf(msg);
        exit(-1);
    }
}

////////////////////////////////////////////////////////////////////////////////
// Program main
////////////////////////////////////////////////////////////////////////////////

int main(int argc, char** argv)
{
    doMatrixMul(argc, argv);
}

////////////////////////////////////////////////////////////////////////////////
//! Run a simple test for CUDA
////////////////////////////////////////////////////////////////////////////////

void doMatrixMul(int argc, char** argv)
{
    int size = 320;
    int devID;
    cudaDeviceProp props;

    checkCudaErrors(cudaGetDevice(&devID));
    checkCudaErrors(cudaGetDeviceProperties(&props, devID));

    int block_size = (props.major < 2) ? 16 : 32;
    unsigned int uiWA, uiHA, uiWB, uiHB, uiWC, uiHC;
    int iSizeMultiple = 5;
	
    uiWA = size;
    uiHA = size;
    uiWB = size;
    uiHB = size;
    uiWC = size;
    uiHC = size;

    // allocate host memory for matrices A and B
    unsigned int size_A = uiWA * uiHA;
    unsigned int mem_size_A = sizeof(float) * size_A;
    float* h_A = (float*)malloc(mem_size_A);
    unsigned int size_B = uiWB * uiHB;
    unsigned int mem_size_B = sizeof(float) * size_B;
    float* h_B = (float*)malloc(mem_size_B);

    // initialize host memory
    srand(2012);
    randomInit(h_A, size_A);
    randomInit(h_B, size_B);
    
    // allocate device memory
    float* d_A, *d_B, *d_C;
    unsigned int size_C = uiWC * uiHC;
    unsigned int mem_size_C = sizeof(float) * size_C;

    // allocate host memory for the result
    float* h_C      = (float*) malloc(mem_size_C);
    float* h_CUBLAS = (float*) malloc(mem_size_C);
    checkCudaErrors(cudaMalloc((void**) &d_A, mem_size_A));
    checkCudaErrors(cudaMalloc((void**) &d_B, mem_size_B));
    // copy host memory to device
    checkCudaErrors(cudaMemcpy(d_A, h_A, mem_size_A, cudaMemcpyHostToDevice) );
    checkCudaErrors(cudaMemcpy(d_B, h_B, mem_size_B, cudaMemcpyHostToDevice) );
    checkCudaErrors(cudaMalloc((void**) &d_C, mem_size_C));
    // setup execution parameters
    dim3 threads(block_size, block_size);
    dim3 grid(uiWC / threads.x, uiHC / threads.y);

    //Performs warmup operation using matrixMul CUDA kernel
    if (block_size == 16) {
            matrixMul<16><<< grid, threads >>>(d_C, d_A, d_B, uiWA, uiWB);
    } else {
            matrixMul<32><<< grid, threads >>>(d_C, d_A, d_B, uiWA, uiWB);
    }
    cudaDeviceSynchronize();

    //shrLog("CUDA matrixMul compares %s\n", (true == resCUDA) ? "OK" : "FAIL");
    // clean up memory
    free(h_A);
    free(h_B);
    free(h_C);
    checkCudaErrors(cudaFree(d_A));
    checkCudaErrors(cudaFree(d_B));
    checkCudaErrors(cudaFree(d_C));
    cudaDeviceReset();
}

// Allocates a matrix with random float entries.
void randomInit(float* data, int size)
{
    for (int i = 0; i < size; ++i)
        data[i] = rand() / (float)RAND_MAX;
}
