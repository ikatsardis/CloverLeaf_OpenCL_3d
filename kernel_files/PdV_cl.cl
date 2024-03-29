#include "./kernel_files/macros_cl.cl"

__kernel void PdV_predict
(double dt,
 __global int * __restrict const error_condition,
 __global const double * __restrict const xarea,
 __global const double * __restrict const yarea,
 __global const double * __restrict const zarea,
 __global const double * __restrict const volume,
 __global const double * __restrict const density0,
 __global double * __restrict const density1,
 __global const double * __restrict const energy0,
 __global double * __restrict const energy1,
 __global const double * __restrict const pressure,
 __global const double * __restrict const viscosity,
 __global const double * __restrict const xvel0,
 __global const double * __restrict const yvel0,
 __global const double * __restrict const zvel0)
{
    __kernel_indexes;

    __local int err_cond_kernel[BLOCK_SZ];
    err_cond_kernel[lid] = 0;

    double volume_change;
    double recip_volume, energy_change, min_cell_volume,
        right_flux, left_flux, top_flux, bottom_flux, total_flux, back_flux, front_flux;
    
    if (/*row >= (y_min + 1) &&*/ row <= (y_max + 1)
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1)
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1))
    {
	left_flux= (xarea[THARR3D(0 ,0 ,0, 1, 0)]*(xvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+xvel0[THARR3D(0 ,1, 0 ,1 ,1)]+xvel0[THARR3D(0 ,0 ,1 ,1 ,1)]+xvel0[THARR3D(0 ,1 ,1, 1 ,1)]
		+xvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+xvel0[THARR3D(0 ,1 ,0 ,1 ,1)]+xvel0[THARR3D(0 ,0 ,1 ,1 ,1)]+xvel0[THARR3D(0 ,1 ,1 ,1 ,1)]))
		*0.125*dt*0.5;

	right_flux= (xarea[THARR3D(1 ,0 ,0 ,1 ,0)]*(xvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+xvel0[THARR3D(1 ,1 ,0 ,1 ,1)]+xvel0[THARR3D(1 ,0 ,1 ,1 ,1)]+xvel0[THARR3D(1 ,1 ,1 ,1 ,1)]
		+xvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+xvel0[THARR3D(1 ,1 ,0 ,1 ,1)]+xvel0[THARR3D(1 ,0 ,1 ,1 ,1)]+xvel0[THARR3D(1 ,1 ,1 ,1 ,1)]))
		*0.125*dt*0.5;

XEON_PHI_LOCAL_MEM_BARRIER;

	bottom_flux=(yarea[THARR3D(0 ,0 ,0 ,0 ,1)]*(yvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+yvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+yvel0[THARR3D(0 ,0 ,1 ,1 ,1)]+yvel0[THARR3D(1 ,0 ,1 ,1 ,1)]
		+yvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+yvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+yvel0[THARR3D(0 ,0 ,1 ,1 ,1)]+yvel0[THARR3D(1 ,0 ,1 ,1 ,1)]))
		*0.125*dt*0.5;

	top_flux= (yarea[THARR3D(0 ,1 ,0 ,0 ,1)]*(yvel0[THARR3D(0 ,1 ,0 ,1 ,1)]+yvel0[THARR3D(1 ,1 ,0 ,1 ,1)]+yvel0[THARR3D(0 ,1 ,1 ,1 ,1)]+yvel0[THARR3D(1 ,1 ,1 ,1 ,1)]
		+yvel0[THARR3D(0 ,1 ,0 ,1 ,1)]+yvel0[THARR3D(1 ,1 ,0 ,1 ,1)]+yvel0[THARR3D(0 ,1 ,1 ,1 ,1)]+yvel0[THARR3D(1 ,1 ,1 ,1 ,1)]))
		*0.125*dt*0.5;

XEON_PHI_LOCAL_MEM_BARRIER;

	back_flux= (zarea[THARR3D(0 ,0 ,0 ,0 ,0)]*(zvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+zvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+zvel0[THARR3D(0 ,1 ,0 ,1 ,1)]+zvel0[THARR3D(1 ,1 ,0 ,1 ,1)]
		+zvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+zvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+zvel0[THARR3D(0 ,1 ,0 ,1 ,1)]+zvel0[THARR3D(1 ,1 ,0 ,1 ,1)]))
		*0.125*dt*0.5;

	front_flux= (zarea[THARR3D(0 ,0 ,1,0,0)]*(zvel0[THARR3D(0 ,0 ,1,1,1)]+zvel0[THARR3D(1,0 ,1,1,1)]+zvel0[THARR3D(0 ,1,1,1,1)]+zvel0[THARR3D(1,1,1,1,1)]
		+zvel0[THARR3D(0 ,0 ,1,1,1)]+zvel0[THARR3D(1,0 ,1,1,1)]+zvel0[THARR3D(0 ,1,1,1,1)]+zvel0[THARR3D(1,1,1,1,1)]))
		*0.125*dt*0.5;


        total_flux=right_flux-left_flux+top_flux-bottom_flux+front_flux-back_flux;

	volume_change=volume[THARR3D(0,0,0,0,0)]/(volume[THARR3D(0,0,0,0,0)]+total_flux);

        //minimum of total, horizontal, and vertical flux

	min_cell_volume=MIN(volume[THARR3D(0,0,0,0,0)]+right_flux-left_flux+top_flux-bottom_flux+front_flux-back_flux
		,MIN(volume[THARR3D(0,0,0,0,0)]+right_flux-left_flux+top_flux-bottom_flux
		,MIN(volume[THARR3D(0,0,0,0,0)]+right_flux-left_flux
		,volume[THARR3D(0,0,0,0,0)]+top_flux-bottom_flux)));

        if(volume_change <= 0.0)
        {
            err_cond_kernel[lid] = 1;
        }
        if(min_cell_volume <= 0.0)
        {
            err_cond_kernel[lid] = 2;
        }

        recip_volume = 1.0/volume[THARR3D(0, 0, 0,0,0)];

        energy_change = (pressure[THARR3D(0, 0, 0,0,0)] / density0[THARR3D(0, 0, 0,0,0)]
            + viscosity[THARR3D(0, 0, 0,0,0)] / density0[THARR3D(0, 0, 0,0,0)])
            * total_flux * recip_volume;

        energy1[THARR3D(0, 0, 0,0,0)] = energy0[THARR3D(0, 0, 0,0,0)] - energy_change;
        density1[THARR3D(0, 0, 0,0,0)] = density0[THARR3D(0, 0, 0,0,0)] * volume_change;
    }
    REDUCTION(err_cond_kernel, error_condition, MAX)
}

__kernel void PdV_not_predict
(double dt,
 __global int * __restrict const error_condition,
 __global const double * __restrict const xarea,
 __global const double * __restrict const yarea,
 __global const double * __restrict const zarea,
 __global const double * __restrict const volume,
 __global const double * __restrict const density0,
 __global double * __restrict const density1,
 __global const double * __restrict const energy0,
 __global double * __restrict const energy1,
 __global const double * __restrict const pressure,
 __global const double * __restrict const viscosity,
 __global const double * __restrict const xvel0,
 __global const double * __restrict const yvel0,
 __global const double * __restrict const zvel0,
 __global const double * __restrict const xvel1,
 __global const double * __restrict const yvel1,
 __global const double * __restrict const zvel1)
{
    __kernel_indexes;

    __local int err_cond_kernel[BLOCK_SZ];
    err_cond_kernel[lid] = 0;

    double volume_change;
    double recip_volume, energy_change, min_cell_volume,
        right_flux, left_flux, top_flux, bottom_flux, total_flux, back_flux, front_flux;
    
    if (/*row >= (y_min + 1) &&*/ row <= (y_max + 1)
    && /*column >= (x_min + 1) &&*/ column <= (x_max + 1)
    && /*slice >= (z_min + 1) &&*/ slice <= (z_max + 1))
    {
	left_flux= (xarea[THARR3D(0 ,0 ,0,1,0)]*(xvel0[THARR3D(0 ,0 ,0,1,1)]+xvel0[THARR3D(0 ,1,0,1,1)]+xvel0[THARR3D(0 ,0 ,1,1,1)]+xvel0[THARR3D(0 ,1,1,1,1)]
		+xvel1[THARR3D(0 ,0 ,0,1,1)]+xvel1[THARR3D(0 ,1,0,1,1)]+xvel1[THARR3D(0 ,0 ,1,1,1)]+xvel1[THARR3D(0 ,1,1,1,1)]))
		*0.125*dt;

	right_flux= (xarea[THARR3D(1,0 ,0,1,0)]*(xvel0[THARR3D(1,0 ,0,1,1)]+xvel0[THARR3D(1,1,0,1,1)]+xvel0[THARR3D(1,0 ,1,1,1)]+xvel0[THARR3D(1,1,1,1,1)]
		+xvel1[THARR3D(1,0 ,0,1,1)]+xvel1[THARR3D(1,1,0,1,1)]+xvel1[THARR3D(1,0 ,1,1,1)]+xvel1[THARR3D(1,1,1,1,1)]))
		*0.125*dt;

XEON_PHI_LOCAL_MEM_BARRIER;

	bottom_flux=(yarea[THARR3D(0 ,0 ,0 ,0 ,1)]*(yvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+yvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+yvel0[THARR3D(0 ,0 ,1 ,1 ,1)]+yvel0[THARR3D(1 ,0 ,1 ,1 ,1)]
		+yvel1[THARR3D(0 ,0 ,0 ,1 ,1)]+yvel1[THARR3D(1 ,0 ,0 ,1 ,1)]+yvel1[THARR3D(0 ,0 ,1 ,1 ,1)]+yvel1[THARR3D(1 ,0 ,1 ,1 ,1)]))
		*0.125*dt;

	top_flux= (yarea[THARR3D(0 ,1 ,0 ,0 ,1)]*(yvel0[THARR3D(0 ,1 ,0 ,1 ,1)]+yvel0[THARR3D(1 ,1 ,0 ,1 ,1)]+yvel0[THARR3D(0 ,1 ,1 ,1 ,1)]+yvel0[THARR3D(1 ,1 ,1 ,1 ,1)]
		+yvel1[THARR3D(0 ,1 ,0 ,1 ,1)]+yvel1[THARR3D(1 ,1 ,0 ,1 ,1)]+yvel1[THARR3D(0 ,1 ,1 ,1 ,1)]+yvel1[THARR3D(1 ,1 ,1 ,1 ,1)]))
		*0.125*dt;

XEON_PHI_LOCAL_MEM_BARRIER;

	back_flux= (zarea[THARR3D(0 ,0 ,0 ,0 ,0)]*(zvel0[THARR3D(0 ,0 ,0 ,1 ,1)]+zvel0[THARR3D(1 ,0 ,0 ,1 ,1)]+zvel0[THARR3D(0 ,1 ,0 ,1 ,1)]+zvel0[THARR3D(1 ,1 ,0 ,1 ,1)]
		+zvel1[THARR3D(0 ,0 ,0 ,1 ,1)]+zvel1[THARR3D(1 ,0 ,0 ,1 ,1)]+zvel1[THARR3D(0 ,1 ,0 ,1 ,1)]+zvel1[THARR3D(1 ,1 ,0 ,1 ,1)]))
		*0.125*dt;

	front_flux= (zarea[THARR3D(0 ,0 ,1,0,0)]*(zvel0[THARR3D(0 ,0 ,1,1,1)]+zvel0[THARR3D(1,0 ,1,1,1)]+zvel0[THARR3D(0 ,1,1,1,1)]+zvel0[THARR3D(1,1,1,1,1)]
		+zvel1[THARR3D(0 ,0 ,1,1,1)]+zvel1[THARR3D(1,0 ,1,1,1)]+zvel1[THARR3D(0 ,1,1,1,1)]+zvel1[THARR3D(1,1,1,1,1)]))
		*0.125*dt;

XEON_PHI_LOCAL_MEM_BARRIER;

	total_flux=right_flux-left_flux+top_flux-bottom_flux+front_flux-back_flux;

	volume_change=volume[THARR3D(0,0,0,0,0)]/(volume[THARR3D(0,0,0,0,0)]+total_flux);

        //minimum of total, horizontal, and vertical flux

	min_cell_volume=MIN(volume[THARR3D(0,0,0,0,0)]+right_flux-left_flux+top_flux-bottom_flux+front_flux-back_flux
		,MIN(volume[THARR3D(0,0,0,0,0)]+right_flux-left_flux+top_flux-bottom_flux
		,MIN(volume[THARR3D(0,0,0,0,0)]+right_flux-left_flux
		,volume[THARR3D(0,0,0,0,0)]+top_flux-bottom_flux)));

        if(volume_change <= 0.0)
        {
            err_cond_kernel[lid] = 1;
        }
        if(min_cell_volume <= 0.0)
        {
            err_cond_kernel[lid] = 2;
        }

        recip_volume = 1.0/volume[THARR3D(0, 0, 0,0,0)];

        energy_change = (pressure[THARR3D(0, 0, 0,0,0)] / density0[THARR3D(0, 0, 0,0,0)]
            + viscosity[THARR3D(0, 0, 0,0,0)] / density0[THARR3D(0, 0, 0,0,0)])
            * total_flux * recip_volume;

        energy1[THARR3D(0, 0, 0,0,0)] = energy0[THARR3D(0, 0, 0,0,0)] - energy_change;
        density1[THARR3D(0, 0, 0,0,0)] = density0[THARR3D(0, 0, 0,0,0)] * volume_change;

    }

    REDUCTION(err_cond_kernel, error_condition, MAX)
}
