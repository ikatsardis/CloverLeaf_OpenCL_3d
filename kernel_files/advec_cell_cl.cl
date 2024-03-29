#include "./kernel_files/macros_cl.cl"
#define _SHARED_KERNEL_ARGS_ \
const int swp_nmbr, \
__global const double* __restrict const vol_flux_x, \
__global const double* __restrict const vol_flux_y, \
__global const double* __restrict const vol_flux_z, \
__global const double* __restrict const pre_vol, \
__global double* __restrict const density1, \
__global double* __restrict const energy1, \
__global double* __restrict const ener_flux

__kernel void advec_cell_pre_vol_x
(const int swp_nmbr,
 __global double* __restrict const pre_vol,
 __global double* __restrict const post_vol,
 __global const double* __restrict const volume,
 __global const double* __restrict const vol_flux_x,
 __global const double* __restrict const vol_flux_y,
 __global const double* __restrict const vol_flux_z)
{
    __kernel_indexes;

    if(/*row >= (y_min + 1) - 2 &&*/ row <= (y_max + 1) + 2
    && /*column >= (x_min + 1) - 2 &&*/ column <= (x_max + 1) + 2
    && /*slice >= (z_min + 1) - 2 &&*/ slice <= (z_max + 1) + 2)
    {
        if(swp_nmbr == 1)
        {
            pre_vol[THARR3D(0,0,0,1,1)]=volume[THARR3D(0,0,0,0,0)] +(vol_flux_x[THARR3D(1,0 ,0,1,0 )]-vol_flux_x[THARR3D(0,0,0,1,0)]
                                                                   + vol_flux_y[THARR3D(0 ,1,0,0,1 )]-vol_flux_y[THARR3D(0,0,0,0,1)]
                                                                   + vol_flux_z[THARR3D(0 ,0 ,1,0,0)]-vol_flux_z[THARR3D(0,0,0,0,0)]);

            post_vol[THARR3D(0,0,0,1,1)]=pre_vol[THARR3D(0,0,0,1,1)]-(vol_flux_x[THARR3D(1,0  ,0,1,0  )]-vol_flux_x[THARR3D(0,0,0,1,0)]);

        }
        else if (swp_nmbr == 3)
        {
            pre_vol[THARR3D(0,0,0,1,1)] =volume[THARR3D(0,0,0,0,0)]+vol_flux_x[THARR3D(1,0 ,0,1,0 )]-vol_flux_x[THARR3D(0,0,0,1,0)];
            post_vol[THARR3D(0,0,0,1,1)]=volume[THARR3D(0,0,0,0,0)];
        }
    }
}

__kernel void advec_cell_ener_flux_x
(_SHARED_KERNEL_ARGS_,
 __global const double* __restrict const vertexdx,
 __global       double* __restrict const mass_flux_x)
{
    __kernel_indexes;

    double sigmat, sigmam, sigma3, sigma4, diffuw, diffdw, limiter;
    int upwind, donor, downwind, dif;
    const double one_by_six = 1.0/6.0;

    //
    // if cell is within x area:
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    // ++xxxxxxxxxxxxxxxxxxx
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    //
    if(/*row >= (y_min + 1) &&*/ row <= (y_max + 1)
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1) + 2
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1))
    {
        // if flowing right
        if(vol_flux_x[THARR3D(0, 0, 0,1,0)] > 0.0)
        {
            upwind = -2;
            donor = -1;
            downwind = 0;
            dif = donor;
        }
        else
        {
            // tries to get from below, unless it would be reading from a cell
            // which would be off the right, in which case read from cur cell
            upwind = (column == (x_max + 1) + 2) ? 0 : 1;
            //upwind = MIN(1,x_max+1+2);
            donor = 0;
            downwind = -1;
            dif = upwind;
        }

        sigmat = fabs(vol_flux_x[THARR3D(0, 0, 0,1,0)]) / pre_vol[THARR3D(donor, 0, 0,1,1)];
        sigma3 = (1.0 + sigmat) * (vertexdx[column] / vertexdx[column + dif]);
        sigma4 = 2.0 - sigmat;

        diffuw = density1[THARR3D(donor, 0, 0,0,0)] - density1[THARR3D(upwind, 0, 0,0,0)];
        diffdw = density1[THARR3D(downwind, 0, 0,0,0)] - density1[THARR3D(donor, 0, 0,0,0)];

        if(diffuw * diffdw > 0.0)
        {
            limiter = (1.0 - sigmat) * SIGN(1.0, diffdw)
                * MIN(fabs(diffuw), MIN(fabs(diffdw), one_by_six
                * (sigma3 * fabs(diffuw) + sigma4 * fabs(diffdw))));
        }
        else
        {
            limiter = 0.0;
        }

        mass_flux_x[THARR3D(0, 0, 0,1,0)] = vol_flux_x[THARR3D(0, 0, 0,1,0)]
            * (density1[THARR3D(donor, 0, 0,0,0)] + limiter);

        sigmam = fabs(mass_flux_x[THARR3D(0, 0, 0,1,0)])
            / (density1[THARR3D(donor, 0, 0,0,0)] * pre_vol[THARR3D(donor, 0, 0,1,1)]);
        diffuw = energy1[THARR3D(donor, 0, 0,0,0)] - energy1[THARR3D(upwind, 0, 0,0,0)];
        diffdw = energy1[THARR3D(downwind, 0, 0,0,0)] - energy1[THARR3D(donor, 0, 0,0,0)];

        if(diffuw * diffdw > 0.0)
        {
            limiter = (1.0 - sigmam) * SIGN(1.0, diffdw)
                * MIN(fabs(diffuw), MIN(fabs(diffdw), one_by_six
                * (sigma3 * fabs(diffuw) + sigma4 * fabs(diffdw))));
        }
        else
        {
            limiter = 0.0;
        }

        ener_flux[THARR3D(0, 0, 0,1,1)] = mass_flux_x[THARR3D(0, 0, 0,1,0)]
            * (energy1[THARR3D(donor, 0, 0,0,0)] + limiter);
    }
}

__kernel void advec_cell_x
(_SHARED_KERNEL_ARGS_,
 __global const double* __restrict const mass_flux_x)
{
    __kernel_indexes;

    double pre_mass, post_mass, advec_vol, post_ener;

    //
    // if cell is within x area:
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    // ++xxxxxxxxxxxxxxxxx++
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    //
    if(/*row >= (y_min + 1) &&*/ row <= (y_max + 1)
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1)
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1))
    {
        pre_mass = density1[THARR3D(0, 0, 0,0,0)] * pre_vol[THARR3D(0, 0, 0,1,1)];

        post_mass = pre_mass + mass_flux_x[THARR3D(0, 0, 0,1,0)]
            - mass_flux_x[THARR3D(1, 0, 0,1,0)];

        post_ener = (energy1[THARR3D(0, 0, 0,0,0)] * pre_mass
            + ener_flux[THARR3D(0, 0, 0,1,1)] - ener_flux[THARR3D(1, 0, 0,1,1)])
            / post_mass;

        advec_vol = pre_vol[THARR3D(0, 0, 0,1,1)] + vol_flux_x[THARR3D(0, 0, 0,1,0)]
            - vol_flux_x[THARR3D(1, 0, 0,1,0)];

        density1[THARR3D(0, 0, 0,0,0)] = post_mass / advec_vol;
        energy1[THARR3D(0, 0, 0,0,0)] = post_ener;
    }
}

//////////////////////////////////////////////////////////////////////////
//y kernels

__kernel void advec_cell_pre_vol_y
(const int swp_nmbr,
 __global double* __restrict const pre_vol,
 __global double* __restrict const post_vol,
 __global const double* __restrict const volume,
 __global const double* __restrict const vol_flux_x,
 __global const double* __restrict const vol_flux_y,
 __global const double* __restrict const vol_flux_z,
int advect_int)
{
    __kernel_indexes;

    if(/*row >= (y_min + 1) - 2 &&*/ row <= (y_max + 1) + 2
    && /*column >= (x_min + 1) - 2 &&*/ column <= (x_max + 1) + 2
    && /*slice >= (z_min + 1) - 2 &&*/ slice <= (z_max + 1) + 2)
    {
        if(swp_nmbr == 2)
        {
            if(advect_int==1)
            {
                pre_vol[THARR3D(0, 0, 0,1,1)] = volume[THARR3D(0, 0, 0,0,0)]
                +(vol_flux_y[THARR3D(0, 1, 0,0,1)] - vol_flux_y[THARR3D(0, 0, 0,0,1)]
                + vol_flux_z[THARR3D(1, 0, 0,0,0)] - vol_flux_z[THARR3D(0, 0, 0,0,0)]);

                post_vol[THARR3D(0, 0, 0,1,1)] = pre_vol[THARR3D(0, 0, 0,1,1)]
                - (vol_flux_y[THARR3D(0, 1, 0,0,1)] - vol_flux_y[THARR3D(0, 0, 0,0,1)]);
            }
            else
            {
                pre_vol[THARR3D(0, 0, 0,1,1)] = volume[THARR3D(0, 0, 0,0,0)]
                +(vol_flux_y[THARR3D(0, 1, 0,0,1)] - vol_flux_y[THARR3D(0, 0, 0,0,1)]
                + vol_flux_x[THARR3D(0, 0, 1,0,0)] - vol_flux_x[THARR3D(0, 0, 0,0,0)]);

                post_vol[THARR3D(0, 0, 0,1,1)] = pre_vol[THARR3D(0, 0, 0,1,1)]
                - (vol_flux_y[THARR3D(0, 1, 0,0,1)] - vol_flux_y[THARR3D(0, 0, 0,0,1)]);
            }
        }
    }
}

__kernel void advec_cell_ener_flux_y
(_SHARED_KERNEL_ARGS_,
 __global const double* __restrict const vertexdy,
 __global double* __restrict const mass_flux_y)
{
    __kernel_indexes;

    double sigmat, sigmam, sigma3, sigma4, diffuw, diffdw, limiter;
    int upwind, donor, downwind, dif;
    const double one_by_six = 1.0/6.0;

    //
    // if cell is within x area:
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    // ++xxxxxxxxxxxxxxxxx++
    // ++xxxxxxxxxxxxxxxxx++
    //
    if(/*row >= (y_min + 1) &&*/ row <= (y_max + 1) + 2
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1)
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1)+2)
    {
        // if flowing up
        if(vol_flux_y[THARR3D(0, 0, 0,0,1)] > 0.0)
        {
            upwind = -2;
            donor = -1;
            downwind = 0;
            dif = donor;
        }
        else
        {
            //
            // tries to get from below, unless it would be reading from a cell
            // which would be off the bottom, in which case read from cur cell
            //
            upwind = (row == (y_max + 1) + 2) ? 0 : 1;
            //upwind = MIN(1,y_max+1+2);
            donor = 0;
            downwind = -1;
            dif = upwind;
        }

        sigmat = fabs(vol_flux_y[THARR3D(0, 0, 0,0,1)]) / pre_vol[THARR3D(0, donor, 0,1,1)];
        sigma3 = (1.0 + sigmat) * (vertexdy[row] / vertexdy[row + dif]);
        sigma4 = 2.0 - sigmat;

        diffuw = density1[THARR3D(0, donor, 0,0,0)] - density1[THARR3D(0, upwind, 0,0,0)];
        diffdw = density1[THARR3D(0, downwind, 0,0,0)] - density1[THARR3D(0, donor, 0,0,0)];

        if(diffuw * diffdw > 0.0)
        {
            limiter = (1.0 - sigmat) * SIGN(1.0, diffdw)
                * MIN(fabs(diffuw), MIN(fabs(diffdw), one_by_six
                * (sigma3 * fabs(diffuw) + sigma4 * fabs(diffdw))));
        }
        else
        {
            limiter = 0.0;
        }

        mass_flux_y[THARR3D(0, 0, 0,0,1)] = vol_flux_y[THARR3D(0, 0, 0,0,1)]
            * (density1[THARR3D(0, donor, 0,0,0)] + limiter);

        sigmam = fabs(mass_flux_y[THARR3D(0, 0, 0,0,1)])
            / (density1[THARR3D(0, donor, 0,0,0)] * pre_vol[THARR3D(0, donor, 0,1,1)]);
        diffuw = energy1[THARR3D(0, donor, 0,0,0)] - energy1[THARR3D(0, upwind, 0,0,0)];
        diffdw = energy1[THARR3D(0, downwind, 0,0,0)] - energy1[THARR3D(0, donor, 0,0,0)];

        if(diffuw * diffdw > 0.0)
        {
            limiter = (1.0 - sigmam) * SIGN(1.0, diffdw)
                * MIN(fabs(diffuw), MIN(fabs(diffdw), one_by_six
                * (sigma3 * fabs(diffuw) + sigma4 * fabs(diffdw))));
        }
        else
        {
            limiter = 0.0;
        }

        ener_flux[THARR3D(0, 0, 0,1,1)] = mass_flux_y[THARR3D(0, 0, 0,0,1)]
            * (energy1[THARR3D(0, donor, 0,0,0)] + limiter);
    }
}

__kernel void advec_cell_y
(_SHARED_KERNEL_ARGS_,
 __global const double* __restrict const mass_flux_y)
{
    __kernel_indexes;

    double pre_mass, post_mass, advec_vol, post_ener;

    //
    // if cell is within x area:
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    // ++xxxxxxxxxxxxxxxxx++
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    //
    if(/*row >= (y_min + 1) &&*/ row <= (y_max + 1)
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1)
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1))
    {
        pre_mass = density1[THARR3D(0, 0, 0,0,0)] * pre_vol[THARR3D(0, 0, 0,1,1)];

        post_mass = pre_mass + mass_flux_y[THARR3D(0, 0, 0,0,1)]
            - mass_flux_y[THARR3D(0, 1, 0,0,1)];

        post_ener = (energy1[THARR3D(0, 0, 0,0,0)] * pre_mass
            + ener_flux[THARR3D(0, 0, 0,1,1)] - ener_flux[THARR3D(0, 1, 0,1,1)])
            / post_mass;

        advec_vol = pre_vol[THARR3D(0, 0,0,1,1)] + vol_flux_y[THARR3D(0, 0, 0,0,1)]
            - vol_flux_y[THARR3D(0, 1, 0,0,1)];

        density1[THARR3D(0, 0, 0,0,0)] = post_mass / advec_vol;
        energy1[THARR3D(0, 0, 0,0,0)] = post_ener;
    }
}
//////////////////////////////////////////////////////////////////////////
//z kernels

__kernel void advec_cell_pre_vol_z
(const int swp_nmbr,
 __global double* __restrict const pre_vol,
 __global double* __restrict const post_vol,
 __global const double* __restrict const volume,
 __global const double* __restrict const vol_flux_x,
 __global const double* __restrict const vol_flux_y,
 __global const double* __restrict const vol_flux_z)
{
    __kernel_indexes;

    if(/*row >= (y_min + 1) - 2 &&*/ row <= (y_max + 1) + 2
    && /*column >= (x_min + 1) - 2 &&*/ column <= (x_max + 1) + 2
    && /*slice >= (z_min + 1) - 2 &&*/ slice <= (z_max + 1) + 2)
    {
        if(swp_nmbr == 1)
        {
            pre_vol[THARR3D(0, 0, 0,1,1)] = volume[THARR3D(0, 0, 0,0,0)]
                +(vol_flux_x[THARR3D(1, 0, 0,1,0)] - vol_flux_x[THARR3D(0, 0, 0,1,0)]
                + vol_flux_y[THARR3D(0, 1, 0,0,1)] - vol_flux_y[THARR3D(0, 0, 0,0,1)]
                + vol_flux_z[THARR3D(0, 0, 1,0,0)] - vol_flux_z[THARR3D(0, 0, 0,0,0)]);

            post_vol[THARR3D(0, 0, 0,1,1)] = pre_vol[THARR3D(0, 0, 0,1,1)]
                - (vol_flux_z[THARR3D(0, 0, 1,0,0)] - vol_flux_z[THARR3D(0, 0, 0,0,0)]);
        }
        else if (swp_nmbr == 3)
        {
            pre_vol[THARR3D(0, 0, 0,1,1)] = volume[THARR3D(0, 0, 0,0,0)]
                + vol_flux_z[THARR3D(0, 0, 1,0,0)] - vol_flux_z[THARR3D(0, 0, 0,0,0)];

            post_vol[THARR3D(0, 0, 0,1,1)] = volume[THARR3D(0, 0, 0,0,0)];
        }
    }
}

__kernel void advec_cell_ener_flux_z
(_SHARED_KERNEL_ARGS_,
 __global const double* __restrict const vertexdz,
 __global double* __restrict const mass_flux_z)
{
    __kernel_indexes;

    double sigmat, sigmam, sigma3, sigma4, diffuw, diffdw, limiter;
    int upwind, donor, downwind, dif;
    const double one_by_six = 1.0/6.0;

    //
    // if cell is within x area:
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    // ++xxxxxxxxxxxxxxxxx++
    // ++xxxxxxxxxxxxxxxxx++
    //
    if(/*row >= (y_min + 1) &&*/ row <= (y_max + 1)
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1)
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1)+2)
    {
        // if flowing up
        if(vol_flux_z[THARR3D(0, 0, 0,0,0)] > 0.0)
        {
            upwind = -2;
            donor = -1;
            downwind = 0;
            dif = donor;
        }
        else
        {
            //
            // tries to get from below, unless it would be reading from a cell
            // which would be off the bottom, in which case read from cur cell
            //
            upwind = (slice == (z_max + 1) + 2) ? 0 : 1;
            //upwind = MIN(1,z_max+1+2);
            donor = 0;
            downwind = -1;
            dif = upwind;
        }

        sigmat = fabs(vol_flux_z[THARR3D(0, 0, 0,0,0)]) / pre_vol[THARR3D(0,0, donor,1,1)];
        sigma3 = (1.0 + sigmat) * (vertexdz[slice] / vertexdz[slice + dif]);
        sigma4 = 2.0 - sigmat;

        diffuw = density1[THARR3D(0,0, donor,0,0)] - density1[THARR3D(0,0, upwind, 0,0)];
        diffdw = density1[THARR3D(0,0, downwind,0,0)] - density1[THARR3D(0,0, donor,0,0)];

        if(diffuw * diffdw > 0.0)
        {
            limiter = (1.0 - sigmat) * SIGN(1.0, diffdw)
                * MIN(fabs(diffuw), MIN(fabs(diffdw), one_by_six
                * (sigma3 * fabs(diffuw) + sigma4 * fabs(diffdw))));
        }
        else
        {
            limiter = 0.0;
        }

        mass_flux_z[THARR3D(0, 0, 0,0,0)] = vol_flux_z[THARR3D(0, 0, 0,0,0)]
            * (density1[THARR3D(0,0, donor,0,0)] + limiter);

        sigmam = fabs(mass_flux_z[THARR3D(0, 0, 0,0,0)])
            / (density1[THARR3D(0,0, donor,0,0)] * pre_vol[THARR3D(0,0, donor,1,1)]);
        diffuw = energy1[THARR3D(0,0, donor,0,0)] - energy1[THARR3D(0,0, upwind,0,0)];
        diffdw = energy1[THARR3D(0,0, downwind,0,0)] - energy1[THARR3D(0,0, donor,0,0)];

        if(diffuw * diffdw > 0.0)
        {
            limiter = (1.0 - sigmam) * SIGN(1.0, diffdw)
                * MIN(fabs(diffuw), MIN(fabs(diffdw), one_by_six
                * (sigma3 * fabs(diffuw) + sigma4 * fabs(diffdw))));

        }
        else
        {
            limiter = 0.0;
        }

        ener_flux[THARR3D(0, 0, 0,1,1)] = mass_flux_z[THARR3D(0, 0, 0,0,0)]
            * (energy1[THARR3D(0,0, donor,0,0)] + limiter);
    }
}

__kernel void advec_cell_z
(_SHARED_KERNEL_ARGS_,
 __global const double* __restrict const mass_flux_z)
{
    __kernel_indexes;

    double pre_mass, post_mass, advec_vol, post_ener;

    //
    // if cell is within x area:
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    // ++xxxxxxxxxxxxxxxxx++
    // +++++++++++++++++++++
    // +++++++++++++++++++++
    //
    if(/*row >= (y_min + 1) &&*/ row <= (y_max + 1)
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1)
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1))
    {
        pre_mass = density1[THARR3D(0, 0, 0,0,0)] * pre_vol[THARR3D(0, 0, 0,1,1)];

        post_mass = pre_mass + mass_flux_z[THARR3D(0, 0, 0,0,0)]
            - mass_flux_z[THARR3D(0, 0, 1,0,0)];

        post_ener = (energy1[THARR3D(0, 0, 0,0,0)] * pre_mass
            + ener_flux[THARR3D(0, 0, 0,1,1)] - ener_flux[THARR3D(0, 0, 1,1,1)])
            / post_mass;

        advec_vol = pre_vol[THARR3D(0, 0,0,1,1)] + vol_flux_z[THARR3D(0, 0, 0,0,0)]
            - vol_flux_z[THARR3D(0, 0, 1,0,0)];

        density1[THARR3D(0, 0, 0,0,0)] = post_mass / advec_vol;
        energy1[THARR3D(0, 0, 0,0,0)] = post_ener;
    }
}
