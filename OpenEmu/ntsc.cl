const sampler_t smp = CLK_NORMALIZED_COORDS_FALSE | //Natural coordinates
CLK_ADDRESS_CLAMP | //Clamp to zeros
CLK_FILTER_NEAREST; //Don't interpolate

enum { snes_ntsc_in_chunk    = 3  };
enum { snes_ntsc_out_chunk   = 7  };
enum { snes_ntsc_black       = 0  };
enum { snes_ntsc_burst_count = 3  };

enum { snes_ntsc_entry_size = 128 };
enum { snes_ntsc_palette_size = 0x2000 };
typedef unsigned long snes_ntsc_rgb_t;

struct snes_ntsc_t {
	unsigned long table[snes_ntsc_palette_size][snes_ntsc_entry_size];
};

enum { snes_ntsc_burst_size = snes_ntsc_entry_size / snes_ntsc_burst_count };

#define SNES_NTSC_IN_FORMAT SNES_NTSC_RGB24

#define SNES_NTSC_BEGIN_ROW( ntsc, burst, pixel0, pixel1, pixel2 ) \
    char const* ktable = \
        (char const*) (ntsc)->table + burst * (snes_ntsc_burst_size * sizeof (snes_ntsc_rgb_t));\
    SNES_NTSC_BEGIN_ROW_6_( pixel0, pixel1, pixel2, SNES_NTSC_IN_FORMAT, ktable )

#define SNES_NTSC_COLOR_IN( index, color ) \
    SNES_NTSC_COLOR_IN_( index, color, SNES_NTSC_IN_FORMAT, ktable )

#define SNES_NTSC_RGB_OUT( index, rgb_out ) \
    SNES_NTSC_RGB_OUT_14_( index, rgb_out, 1 )

#define SNES_NTSC_RGB24( ktable, n ) \
    (snes_ntsc_rgb_t const*) (ktable + ((n >> 3 & 0x001E) | (n >> 6 & 0x03E0) | (n >> 10 & 0x3C00)) * \
    (snes_ntsc_entry_size / 2 * sizeof (snes_ntsc_rgb_t)))

#define SNES_NTSC_BEGIN_ROW_6_( pixel0, pixel1, pixel2, ENTRY, table ) \
    unsigned const snes_ntsc_pixel0_ = (pixel0);\
    snes_ntsc_rgb_t const* kernel0  = ENTRY( table, snes_ntsc_pixel0_ );\
    unsigned const snes_ntsc_pixel1_ = (pixel1);\
    snes_ntsc_rgb_t const* kernel1  = ENTRY( table, snes_ntsc_pixel1_ );\
    unsigned const snes_ntsc_pixel2_ = (pixel2);\
    snes_ntsc_rgb_t const* kernel2  = ENTRY( table, snes_ntsc_pixel2_ );\
    snes_ntsc_rgb_t const* kernelx0;\
    snes_ntsc_rgb_t const* kernelx1 = kernel0;\
    snes_ntsc_rgb_t const* kernelx2 = kernel0

#define SNES_NTSC_RGB_OUT_14_( x, rgb_out, shift ) {\
    snes_ntsc_rgb_t raw_ =\
    kernel0  [x       ] + kernel1  [(x+12)%7+14] + kernel2  [(x+10)%7+28] +\
    kernelx0 [(x+7)%14] + kernelx1 [(x+ 5)%7+21] + kernelx2 [(x+ 3)%7+35];\
    SNES_NTSC_CLAMP_( raw_, shift );\
    SNES_NTSC_RGB_OUT_( rgb_out );\
}

/* common ntsc macros */
#define snes_ntsc_rgb_builder    ((1L << 21) | (1 << 11) | (1 << 1))
#define snes_ntsc_clamp_mask     (snes_ntsc_rgb_builder * 3 / 2)
#define snes_ntsc_clamp_add      (snes_ntsc_rgb_builder * 0x101)
#define SNES_NTSC_CLAMP_( io, shift ) {\
    snes_ntsc_rgb_t sub = (io) >> (9-(shift)) & snes_ntsc_clamp_mask;\
    snes_ntsc_rgb_t clamp = snes_ntsc_clamp_add - sub;\
    io |= clamp;\
    clamp -= sub;\
    io &= clamp;\
}

#define SNES_NTSC_COLOR_IN_( index, color, ENTRY, table ) {\
    unsigned color_;\
    kernelx##index = kernel##index;\
    kernel##index = (color_ = (color), ENTRY( table, color_ ));\
}

#define SNES_NTSC_RGB_OUT_( rgb_out ) {\
    unsigned int test = (raw_>>5&0xFF0000)|(raw_>>3&0xFF00)|(raw_>>1&0xFF);\
    float4 res;\
    res.r = (test >> 24 & 0xFF) / 255.0f;\
    res.g = (test >> 24 & 0xFF) / 255.0f;\
    res.b = (test >> 24 & 0xFF) / 255.0f;\
    res.a = 1.0f;\
    write_imagef(output, (int2)(rgb_out,y), res);\
}


unsigned int read_pixel(image2d_t input, int x, int y)
{
    float4 pixel = read_imagef(input, smp,(int2) (x,y));

    return (unsigned int) ((unsigned int)(255 * pixel.x) << 24) | ((unsigned int)(255 * pixel.y) << 16) | ((unsigned int)(255 * pixel.z) << 8);
}


kernel void ntsc_blit(global void *ntsc_void, read_only image2d_t input, write_only image2d_t output)
{
    int y = get_global_id(0);
    if(y >= get_image_height(output))
        return;
/*
    int2 coords = (int2) (x,y);

    unsigned int test = read_pixel(input, x, y);

    float4 res;// = (float4) ((test >> 16 & 0xFF) / 255.0f,(test >> 8 & 0xFF) / 255.0f,(test & 0xFF) / 255.0f,1.0f);


    res.r = (test >> 24 & 0xFF) / 255.0f;
    res.g = (test >> 16 & 0xFF) / 255.0f;
    res.b = (test >> 8 & 0xFF) / 255.0f;
    res.a = 1.0f;


    //res = (float4) (1.0f,1.0f,0.0f,1.0f);

    write_imagef(output, coords, res);
*/
    
    int burst_phase = 0;
    int x_in = 0;
    int x_out = 0;
    
    int chunk_count = (256 - 1) / 12;
    global struct snes_ntsc_t *ntsc = ntsc_void;

    SNES_NTSC_BEGIN_ROW( ntsc, burst_phase, snes_ntsc_black, snes_ntsc_black, read_pixel(input, x_in, y) );
    /*
    char const* ktable = (char const*) (ntsc)->table + burst_phase * (snes_ntsc_burst_size * sizeof (snes_ntsc_rgb_t));
    //SNES_NTSC_BEGIN_ROW_6_( pixel0, pixel1, pixel2, SNES_NTSC_IN_FORMAT, ktable )
    unsigned const snes_ntsc_pixel0_ = snes_ntsc_black;
    snes_ntsc_rgb_t const* kernel0  = (snes_ntsc_rgb_t const*) (ktable + ((snes_ntsc_pixel0_ >> 3 & 0x001E) | (snes_ntsc_pixel0_ >> 6 & 0x03E0) | (snes_ntsc_pixel0_ >> 10 & 0x3C00)) * (snes_ntsc_entry_size / 2 * sizeof (snes_ntsc_rgb_t)));
    unsigned const snes_ntsc_pixel1_ = snes_ntsc_black;
    snes_ntsc_rgb_t const* kernel1  = (snes_ntsc_rgb_t const*) (ktable + ((snes_ntsc_pixel1_ >> 3 & 0x001E) | (snes_ntsc_pixel1_ >> 6 & 0x03E0) | (snes_ntsc_pixel1_ >> 10 & 0x3C00)) * (snes_ntsc_entry_size / 2 * sizeof (snes_ntsc_rgb_t)));
    unsigned const snes_ntsc_pixel2_ = read_pixel(input, x_in, y);
    snes_ntsc_rgb_t const* kernel2  = (snes_ntsc_rgb_t const*) (ktable + ((snes_ntsc_pixel2_ >> 3 & 0x001E) | (snes_ntsc_pixel2_ >> 6 & 0x03E0) | (snes_ntsc_pixel2_ >> 10 & 0x3C00)) * (snes_ntsc_entry_size / 2 * sizeof (snes_ntsc_rgb_t)));
    snes_ntsc_rgb_t const* kernelx0;
    snes_ntsc_rgb_t const* kernelx1 = kernel0;
    snes_ntsc_rgb_t const* kernelx2 = kernel0;
     */
    
    int n;

    for ( n = chunk_count; n; --n )
    {
        // order of input and output pixels must not be altered
        SNES_NTSC_COLOR_IN( 0, read_pixel(input, ++x_in, y) );
        /*
        {
            unsigned color_;
            kernelx0 = kernel0;
            kernel0 = (color_ = (read_pixel(input, ++x_in, y)), (snes_ntsc_rgb_t const*) (ktable + ((color_ >> 3 & 0x001E) | (color_ >> 6 & 0x03E0) | (color_ >> 10 & 0x3C00)) * (snes_ntsc_entry_size / 2 * sizeof (snes_ntsc_rgb_t))));
        }
        */
        SNES_NTSC_RGB_OUT( 0, x_out );
        //#define SNES_NTSC_RGB_OUT_14_( x, rgb_out, shift )
        /*
        {
            snes_ntsc_rgb_t raw_ =
            kernel0  [0       ] + kernel1  [(0+12)%7+14] + kernel2  [(0+10)%7+28] +
            kernelx0 [(0+7)%14] + kernelx1 [(0+ 5)%7+21] + kernelx2 [(0+ 3)%7+35];
            //SNES_NTSC_CLAMP_( raw_, shift );
            //#define SNES_NTSC_CLAMP_( io, shift )
            {
                snes_ntsc_rgb_t sub = (raw_) >> (9-(1)) & snes_ntsc_clamp_mask;
                snes_ntsc_rgb_t clamp = snes_ntsc_clamp_add - sub;
                raw_ |= clamp;
                clamp -= sub;
                raw_ &= clamp;
            }
            //SNES_NTSC_RGB_OUT_( rgb_out );
            
            {
                unsigned int test = (raw_>>5&0xFF0000)|(raw_>>3&0xFF00)|(raw_>>1&0xFF);
                float4 res;
                //printf("hello");
                //printf("%f\n", (test >> 16 & 0xFF) / 255.0f);
                //printf("%f\n", (test >> 8 & 0xFF) / 255.0f);
                res.r = (test >> 24 & 0xFF) / 255.0f;
                res.g = (test >> 24 & 0xFF) / 255.0f;
                res.b = (test >> 24 & 0xFF) / 255.0f;
                res.a = 1.0f;
                write_imagef(output, (int2)(x_out,y), res);
            }
             
        }
        */
        ++x_out;
        SNES_NTSC_RGB_OUT( 1, x_out );
        ++x_out;

        SNES_NTSC_COLOR_IN( 1, read_pixel(input, ++x_in, y) );
        SNES_NTSC_RGB_OUT( 2, x_out );
        ++x_out;
        SNES_NTSC_RGB_OUT( 3, x_out );
        ++x_out;

        SNES_NTSC_COLOR_IN( 2, read_pixel(input, ++x_in, y) );
        SNES_NTSC_RGB_OUT( 4, x_out );
        ++x_out;
        SNES_NTSC_RGB_OUT( 5, x_out );
        ++x_out;
        SNES_NTSC_RGB_OUT( 6, x_out );
        ++x_out;
    }

   /*
    // finish final pixels
    SNES_NTSC_COLOR_IN( 0, snes_ntsc_black );
    SNES_NTSC_RGB_OUT( 0 );
    ++x2;
    SNES_NTSC_RGB_OUT( 1 );
    ++x2;

    SNES_NTSC_COLOR_IN( 1, snes_ntsc_black );
    SNES_NTSC_RGB_OUT( 2 );
    ++x2;
    SNES_NTSC_RGB_OUT( 3 );
    ++x2;

    SNES_NTSC_COLOR_IN( 2, snes_ntsc_black );
    SNES_NTSC_RGB_OUT( 4 );
    ++x2;
    SNES_NTSC_RGB_OUT( 5 );
    ++x2;
    SNES_NTSC_RGB_OUT( 6 );
    ++x2;*/

    //burst_phase = (burst_phase + 1) % snes_ntsc_burst_count;
}

kernel void turn(global void *ntsc_void, read_only image2d_t image2, write_only image2d_t image1)
{
    int x = get_global_id(0);
    int y = get_global_id(1);

    global struct snes_ntsc_t *ntsc = ntsc_void;

    int2 coords = (int2) (x,y);

    float4 val = read_imagef(image2, smp,(int2) (x,y));

    float4 res = (float4) (val.x, ntsc->table[x][y], 0.0f, 1.0f);

    write_imagef(image1, coords, res);

    //printf("test");
}
