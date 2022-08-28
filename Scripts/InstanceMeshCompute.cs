using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class InstanceMeshCompute : MonoBehaviour
{
    public int instanceCountx = 1024;
    public Mesh instanceMesh;
    public Material instanceMaterial;
    public int subMeshIndex = 0;
    public ComputeShader computer;
    //public TerrainData terrain;
    public Transform pusher;
    private int kernelNum;
    private ComputeBuffer positionBuffer;
    private ComputeBuffer pushersBuffer;
    private ComputeBuffer argsBuffer;
    //private ComputeBuffer heightsBuffer;
    private uint[] args = new uint[5] { 0, 0, 0, 0, 0 };
    //private float[] heights;

    /*
    float[] To1DArray(float[,] input)
    {
        // Step 1: get total size of 2D array, and allocate 1D array.
        int size = input.Length;
        float[] result = new float[size];

        // Step 2: copy 2D array elements into a 1D array.
        int write = 0;
        for (int i = 0; i <= input.GetUpperBound(0); i++)
        {
            for (int z = 0; z <= input.GetUpperBound(1); z++)
            {
                result[write++] = input[i, z];
            }
        }
        // Step 3: return the new array.
        return result;
    }
    */



    void Start()
    {
        //heights = new float[instanceCountx];
        //heights = To1DArray( terrain.GetHeights(0, 0, instanceCountx, instanceCounty));
        argsBuffer = new ComputeBuffer(1, args.Length * sizeof(uint), ComputeBufferType.IndirectArguments);
        //heightsBuffer = new ComputeBuffer(instanceCountx, 4);
        //heightsBuffer.SetData(heights);
        UpdateBuffers();
        kernelNum = computer.FindKernel("CSMain");
    }

    void UpdateBuffers()
    {
        // Ensure submesh index is in range
        if (instanceMesh != null)
            subMeshIndex = Mathf.Clamp(subMeshIndex, 0, instanceMesh.subMeshCount - 1);

        // Positions
        if (positionBuffer != null)
            positionBuffer.Release();
        positionBuffer = new ComputeBuffer(instanceCountx, 11 * 4);
        pushersBuffer = new ComputeBuffer(1, 16);
        Vector4[] pusherPos = new Vector4[] { new Vector4(pusher.position.x, pusher.position.y, pusher.position.z, 10) };
        pushersBuffer.SetData(pusherPos);
        //dispatch compute shader
        computer.SetFloat("xSize", instanceCountx);
        computer.SetBuffer(kernelNum, "positionBuffer", positionBuffer);
        //computer.SetBuffer(kernelNum, "heightMap", heightsBuffer);
        computer.SetBuffer(kernelNum, "grassPushers", pushersBuffer);
        computer.Dispatch(kernelNum, instanceCountx / 8, 1, 1);
        instanceMaterial.SetBuffer("positionBuffer", positionBuffer);

        // Indirect args
        if (instanceMesh != null)
        {
            args[0] = (uint)instanceMesh.GetIndexCount(subMeshIndex);
            args[1] = (uint)(instanceCountx);
            args[2] = (uint)instanceMesh.GetIndexStart(subMeshIndex);
            args[3] = (uint)instanceMesh.GetBaseVertex(subMeshIndex);
        }
        else
        {
            args[0] = args[1] = args[2] = args[3] = 0;
        }
        argsBuffer.SetData(args);

    }

    // Update is called once per frame
    void Update()
    {
        //set compute shader values and dispatch
        computer.SetFloat("time", Time.time);
        Vector4[] pusherPos = new Vector4[] { new Vector4(pusher.position.x, pusher.position.y, pusher.position.z, 10) };
        pushersBuffer.SetData(pusherPos);
        Vector3 floorValue = new Vector3(transform.position.x, 0, transform.position.z);
        computer.SetFloats("cameraPosition", new float[] { floorValue.x, 0, floorValue.z });
        computer.SetFloats("cameraForward", new float[] { transform.forward.x, transform.forward.y, transform.forward.z });
        computer.SetFloats("cameraRight", new float[] { transform.right.x, transform.right.y, transform.right.z });
        computer.SetFloat("numPushers", 1);
        computer.Dispatch(kernelNum, instanceCountx / 128, 1, 1);

        //draw the grass
        Graphics.DrawMeshInstancedIndirect(instanceMesh, subMeshIndex, instanceMaterial, new Bounds(Vector3.zero, new Vector3(10000.0f, 10000f, 10000.0f)), argsBuffer);

    }

    private void OnDisable()
    {
        //tidy our buffers away
        argsBuffer.Dispose();
        positionBuffer.Dispose();
        pushersBuffer.Dispose();
    }
}
