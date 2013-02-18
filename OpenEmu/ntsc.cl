const sampler_t smp = CLK_NORMALIZED_COORDS_FALSE | //Natural coordinates
CLK_ADDRESS_CLAMP | //Clamp to zeros
CLK_FILTER_NEAREST; //Don't interpolate

kernel void turn(write_only image2d_t image1, read_only image2d_t image2)
{
    int x = get_global_id(0);
    int y = get_global_id(1);

    int2 coords = (int2) (x,y);

    float4 val = read_imagef(image2, smp, coords);

    float4 res = (float4) (val.x, 0.0f, 0.0f, 1.0f);

    write_imagef(image1, coords, res);
}
