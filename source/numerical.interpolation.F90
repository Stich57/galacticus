!! Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018,
!!           2019, 2020, 2021
!!    Andrew Benson <abenson@carnegiescience.edu>
!!
!! This file is part of Galacticus.
!!
!!    Galacticus is free software: you can redistribute it and/or modify
!!    it under the terms of the GNU General Public License as published by
!!    the Free Software Foundation, either version 3 of the License, or
!!    (at your option) any later version.
!!
!!    Galacticus is distributed in the hope that it will be useful,
!!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!!    GNU General Public License for more details.
!!
!!    You should have received a copy of the GNU General Public License
!!    along with Galacticus.  If not, see <http://www.gnu.org/licenses/>.

!% Contains a module which acts as a simple interface to the \href{http://www.gnu.org/software/gsl/}{GNU Scientific Library}
!% \href{http://www.gnu.org/software/gsl/manual/html_node/Interpolation.html}{interpolation routines}.

! Specify an explicit dependence on the interface.GSL.C.interpolation.o object file.
!: $(BUILDPATH)/interface.GSL.C.interpolation.o

! Add dependency on GSL library.
!; gsl

module Numerical_Interpolation
  !% A simple interface to the \href{http://www.gnu.org/software/gsl/}{GNU Scientific Library}
  !% \href{http://www.gnu.org/software/gsl/manual/html_node/Interpolation.html}{interpolation routines}.
  use, intrinsic :: ISO_C_Binding, only : c_ptr, c_size_t, c_int, c_double
  implicit none
  private
  public :: interpolator

  ! Interpolator types.
  integer, public, parameter :: gsl_interp_linear          =1
  integer, public, parameter :: gsl_interp_polynomial      =2
  integer, public, parameter :: gsl_interp_cspline         =3
  integer, public, parameter :: gsl_interp_cspline_periodic=4
  integer, public, parameter :: gsl_interp_akima           =5
  integer, public, parameter :: gsl_interp_akima_periodic  =6

  interface
     function gsl_interp_alloc(T,size) bind(c,name='gsl_interp_alloc')
       !% Template for GSL interface interpolation allocation function.
       import c_ptr, c_size_t
       type   (c_ptr   )        :: gsl_interp_alloc
       type   (c_ptr   ), value :: T
       integer(c_size_t), value :: size
     end function gsl_interp_alloc

     function gsl_interp_init(interp,xa,ya,size) bind(c,name='gsl_interp_init')
       !% Template for GSL interface interpolation initialization function.
       import c_ptr, c_size_t, c_int, c_double
       integer(c_int   )               :: gsl_interp_init
       type   (c_ptr   ), value        :: interp
       real   (c_double), dimension(*) :: xa             , ya
       integer(c_size_t), value        :: size
     end function gsl_interp_init

     function gsl_interp_eval_e(interp,xa,ya,x,acc,y) bind(c,name='gsl_interp_eval_e')
       !% Template for GSL interface interpolation function.
       import c_ptr, c_size_t, c_int, c_double
       integer(c_int   )               :: gsl_interp_eval_e
       type   (c_ptr   ), value        :: interp
       real   (c_double), dimension(*) :: xa               , ya
       real   (c_double), value        :: x
       type   (c_ptr   ), value        :: acc
       real   (c_double)               :: y
     end function gsl_interp_eval_e
     
     function gsl_interp_eval_deriv_e(interp,xa,ya,x,acc,d) bind(c,name='gsl_interp_eval_deriv_e')
       !% Template for GSL interface interpolation function.
       import c_ptr, c_size_t, c_int, c_double
       integer(c_int   )               :: gsl_interp_eval_deriv_e
       type   (c_ptr   ), value        :: interp
       real   (c_double), dimension(*) :: xa                     , ya
       real   (c_double), value        :: x
       type   (c_ptr   ), value        :: acc
       real   (c_double)               :: d
     end function gsl_interp_eval_deriv_e
     
     subroutine gsl_interp_free(interp) bind(c,name='gsl_interp_free')
       !% Template for GSL interface interpolation free function.
       import c_ptr
       type(c_ptr), value :: interp
     end subroutine gsl_interp_free

     function gsl_interp_accel_alloc() bind(c,name='gsl_interp_accel_alloc')
       !% Template for GSL interface interpolation accelerator allocation function.
       import c_ptr
       type(c_ptr) :: gsl_interp_accel_alloc
     end function gsl_interp_accel_alloc

     function gsl_interp_accel_find(a,x_array,size,x) bind(c,name='gsl_interp_accel_find')
       !% Template for GSL interface interpolation accelerator allocation function.
       import c_ptr, c_size_t, c_double
       integer(c_size_t)               :: gsl_interp_accel_find
       type   (c_ptr   ), value        :: a
       real   (c_double), dimension(*) :: x_array
       integer(c_size_t), value        :: size
       real   (c_double), value        :: x
     end function gsl_interp_accel_find

     subroutine gsl_interp_accel_free(acc) bind(c,name='gsl_interp_accel_free')
       !% Template for GSL interface interpolation accelerator free function.
       import c_ptr
       type(c_ptr), value :: acc
     end subroutine gsl_interp_accel_free

     function gsl_interp_type_get(i) bind(c,name='gsl_interp_type_get')
       !% Template for GSL interface interpolation type function.
       import c_ptr, c_int
       type   (c_ptr)                       :: gsl_interp_type_get
       integer(c_int), intent(in   ), value :: i
     end function gsl_interp_type_get
  end interface

  !# <stateStorable class="interpolator">
  !#  <interpolator>
  !#   <restoreTo  variables="initialized" state=".false."/>
  !#   <methodCall method="GSLReallocate" arguments="gslFree=.true." />
  !#  </interpolator>
  !# </stateStorable>

  !# <deepCopyActions class="interpolator">
  !#  <interpolator>
  !#   <methodCall method="GSLReallocate" arguments="gslFree=.false."/>
  !#  </interpolator>
  !# </deepCopyActions>

  type :: interpolator
     !% Type providing interpolation in 1-D arrays.
     private
     type            (c_ptr   ), allocatable               :: gsl_interp       , gsl_interp_accel , &
          &                                                   gsl_interp_type
     integer                                               :: extrapolationType, interpolationType
     integer         (c_size_t)                            :: countArray
     logical                                               :: initialized      , interpolatable
     double precision          , allocatable, dimension(:) :: x                , y 
   contains
     !# <methods>
     !#   <method description="Interpolate in the tabulated function." method="interpolate" />
     !#   <method description="Interpolate the derivative in the tabulated function." method="derivative" />
     !#   <method description="Locate the position in the array corresponding to the given {\normalfont \ttfamily x}." method="locate" />
     !#   <method description="Return factors required to perform a linear interpolation." method="linearFactors" />
     !#   <method description="Return weights required to perform a linear interpolation." method="linearWeights" />
     !#   <method description="Allocate GSL objects." method="gslAllocate" />
     !#   <method description="Reallocate GSL objects." method="gslReallocate" />
     !#   <method description="Initialize GSL interpolator." method="gslInitialize" />
     !#   <method description="Assert that the data is interpolatable." method="assertInterpolatable" />
     !# </methods>
     final     ::                         interpolatorDestructorRank0       , &
          &                               interpolatorDestructorRank1       , &
          &                               interpolatorDestructorRank2
     procedure ::                         interpolatorInterpolate
     procedure ::                         interpolatorInterpolateNoYa
     generic   :: interpolate          => interpolatorInterpolate           , &
          &                               interpolatorInterpolateNoYa
     procedure ::                         interpolatorDerivative
     procedure ::                         interpolatorDerivativeNoYa
     generic   :: derivative           => interpolatorDerivative            , &
          &                               interpolatorDerivativeNoYa
     procedure :: linearFactors        => interpolatorLinearFactors
     procedure :: linearWeights        => interpolatorLinearWeights
     procedure :: locate               => interpolatorLocate
     procedure :: gslAllocate          => interpolatorGSLAllocate
     procedure :: gslReallocate        => interpolatorGSLReallocate
     procedure :: gslInitialize        => interpolatorGSLInitialize
     procedure :: assertInterpolatable => interpolatorAssertInterpolatable
  end type interpolator

  interface interpolator
     !% Constructor for the {\normalfont \ttfamily interpolator} class.
     module procedure interpolatorConstructor
  end interface interpolator
  
contains

  function interpolatorConstructor(x,y,interpolationType,extrapolationType) result(self)
    !% Constructor for {\normalfont \ttfamily interpolator} obejcts.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    use :: Table_Labels    , only : extrapolationTypeAbort
    implicit none
    type            (interpolator)                                        :: self
    double precision              , intent(in   ), dimension(:)           :: x
    double precision              , intent(in   ), dimension(:), optional :: y
    integer                       , intent(in   )              , optional :: interpolationType, extrapolationType
    !# <optionalArgument name="interpolationType" defaultsTo="gsl_interp_linear"     />
    !# <optionalArgument name="extrapolationType" defaultsTo="extrapolationTypeAbort"/>
    
    ! Validate data.
    if    (size(x) <                       1 ) call Galacticus_Error_Report('"x" must contain at least 1 datapoint'  //{introspection:location})
    if (present(y)) then
       if (size(x) ==      1 ) call Galacticus_Error_Report('"x" must contain at least 2 datapoints' //{introspection:location})
       if (size(x) /= size(y)) call Galacticus_Error_Report('"x" and "y" arrays must be of same size'//{introspection:location})
    end if
    ! Store extrapolation.
    self%extrapolationType=extrapolationType_
    ! Get the interpolator type.
    self%interpolationType=interpolationType_
    self%gsl_interp_type=gsl_interp_type_get(interpolationType_)
    ! Store data.
    self%countArray=size(x)
    allocate   (self%x(self%countArray))
    self%x         =     x
    if (present(y)) then
       allocate(self%y(self%countArray))
       self%y=y
    end if
    ! Determine if the data is interpolatable.
    self%interpolatable=self%countArray > 1
    ! Allocate GSL interpolation objects.
    call self%GSLAllocate()
    return
  end function interpolatorConstructor

  subroutine interpolatorDestructorRank0(self)
    !% Destructor for rank-0 {\normalfont \ttfamily interpolator} objects.
    implicit none
    type(interpolator), intent(inout) :: self

    if (allocated (self%gsl_interp      )) then
       call gsl_interp_free      (self%gsl_interp      )
       deallocate(self%gsl_interp      )
    end if
    if (allocated (self%gsl_interp_accel)) then
       call gsl_interp_accel_free(self%gsl_interp_accel)
       deallocate(self%gsl_interp_accel)
    end if
    return
  end subroutine interpolatorDestructorRank0
  
  subroutine interpolatorDestructorRank1(self)
    !% Destructor for rank-1 {\normalfont \ttfamily interpolator} objects.
    implicit none
    type   (interpolator), intent(inout), dimension(:) :: self
    integer                                            :: i1
    
    do i1=1,size(self,dim=1)
       call interpolatorDestructorRank0(self(i1))
    end do
    return
  end subroutine interpolatorDestructorRank1
  
  subroutine interpolatorDestructorRank2(self)
    !% Destructor for rank-2 {\normalfont \ttfamily interpolator} objects.
    implicit none
    type   (interpolator), intent(inout), dimension(:,:) :: self
    integer                                              :: i1  , i2
    
    do i1=1,size(self,dim=1)
       do i2=1,size(self,dim=2)
          call interpolatorDestructorRank0(self(i1,i2))
       end do
    end do
    return
  end subroutine interpolatorDestructorRank2
  
  subroutine interpolatorGSLAllocate(self)
    !% Allocate GSL objects.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    use :: Interface_GSL   , only : GSL_Success
    implicit none
    class(interpolator), intent(inout) :: self

    if (.not.allocated(self%gsl_interp      ) .and. self%interpolatable) then
       allocate(self%gsl_interp      )
       self%gsl_interp=gsl_interp_alloc            (self%gsl_interp_type,self%countArray)
    end if
    if (.not.allocated(self%gsl_interp_accel)                          ) then
       allocate(self%gsl_interp_accel)
       self%gsl_interp_accel=gsl_interp_accel_alloc(                                    )
    end if
    ! Initialize.
    self%initialized=.false.
    if (allocated(self%y)) then
       ! A y-array was provided, so we can initialize normally.
       call self%GSLInitialize(self%y)
    else if (self%interpolationType /= gsl_interp_linear) then
       ! For linear interpolation only we can handle having no y-array (since the GSL linear interpolator makes no use of this
       ! during initialization). In this case we defer initialization until needed.
       call Galacticus_Error_Report('a y-array must be provided (except for linear interpolators)'//{introspection:location})
    end if
    return
  end subroutine interpolatorGSLAllocate

  subroutine interpolatorGSLReallocate(self,gslFree)
    !% Reallocate GSL objects.
    use, intrinsic :: ISO_C_Binding, only : c_null_ptr
    implicit none
    class  (interpolator), intent(inout) :: self
    logical              , intent(in   ) :: gslFree
    
    if (allocated(self%gsl_interp      )) then
       if (gslFree) then
          call gsl_interp_free      (self%gsl_interp      )
       else
          self%gsl_interp=c_null_ptr
       end if
       deallocate(self%gsl_interp      )
    end if
    if (allocated(self%gsl_interp_accel)) then
       if (gslFree) then
          call gsl_interp_accel_free(self%gsl_interp_accel)
       else
          self%gsl_interp_accel=c_null_ptr
       end if
       deallocate(self%gsl_interp_accel)
    end if
    ! If x() is not allocated, then this interpolator was never initialized - so do not attempt to allocate any GSL objects.
    if (.not.allocated(self%x)) return
    ! Re-establish the interpolation type if necessary.
    if (.not.allocated(self%gsl_interp_type)) then
       allocate(self%gsl_interp_type)
       self%gsl_interp_type=gsl_interp_type_get(self%interpolationType)
    end if
    call self%GSLAllocate()
    return
  end subroutine interpolatorGSLReallocate

  subroutine interpolatorGSLInitialize(self,ya)
    !% Initialize GSL interpoltor.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    use :: Interface_GSL   , only : GSL_Success
    implicit none
    class           (interpolator), intent(inout)               :: self
    double precision              , intent(in   ), dimension(:) :: ya
    integer         (c_int       )                              :: status

    status=gsl_interp_init(self%gsl_interp,self%x,ya,self%countArray)
    if (status /= GSL_Success) call Galacticus_Error_Report('failed to initialize interpolator'//{introspection:location})
    self%initialized=.true.
    return
  end subroutine interpolatorGSLInitialize

  subroutine interpolatorAssertInterpolatable(self)
    !% Assert that the data is interpolatable.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    class(interpolator), intent(inout) :: self

    if (.not.self%interpolatable) call Galacticus_Error_Report('data is not interpolatable'//{introspection:location})
    return
  end subroutine interpolatorAssertInterpolatable
  
  subroutine interpolatorLinearFactors(self,x,i,h)
    !% Return interpolating factors for linear interpolation in the array {\normalfont \ttfamily xArray()} given {\normalfont \ttfamily x}.
    implicit none
    class           (interpolator)                , intent(inout) :: self
    double precision                              , intent(in   ) :: x
    integer         (c_size_t    )                , intent(  out) :: i
    double precision              , dimension(0:1), intent(  out) :: h

    call self%assertInterpolatable()
    i=self%locate(x)
    call self%linearWeights(x,i,h)
    return
  end subroutine interpolatorLinearFactors

  subroutine interpolatorLinearWeights(self,x,i,h)
    !% Return interpolation weights factors for linear interpolation in the array {\normalfont \ttfamily xArray()} given {\normalfont \ttfamily x} and {\normalfont \ttfamily i}.
    implicit none
    class           (interpolator)                , intent(inout) :: self
    double precision                              , intent(in   ) :: x
    integer         (c_size_t    )                , intent(in   ) :: i
    double precision              , dimension(0:1), intent(  out) :: h

    call self%assertInterpolatable()
    h(0)   =+(self%x(i+1)-     x   ) &
         &  /(self%x(i+1)-self%x(i))
    h(1)   =1.0d0-h(0)
    return
  end subroutine interpolatorLinearWeights

  double precision function interpolatorInterpolateNoYa(self,x)
    !% Interpolate a function to {\normalfont \ttfamily x}.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    class           (interpolator  ), intent(inout) :: self
    double precision                , intent(in   ) :: x

    if (allocated(self%y)) then
       interpolatorInterpolateNoYa=self%interpolate(x,self%y)
    else
       interpolatorInterpolateNoYa=0.0d0
       call Galacticus_Error_Report("no y() array specified"//{introspection:location})       
    end if
    return
  end function interpolatorInterpolateNoYa
  
  double precision function interpolatorInterpolate(self,x,ya)
    !% Interpolate a function to {\normalfont \ttfamily x}.
    use :: Galacticus_Error  , only : Galacticus_Error_Report
    use :: Interface_GSL     , only : GSL_Success            , GSL_EDom
    use :: ISO_Varying_String, only : assignment(=)          , operator(//)                , varying_string
    use :: Table_Labels      , only : extrapolationTypeAbort , extrapolationTypeExtrapolate, extrapolationTypeFix
    implicit none
    class           (interpolator  ), intent(inout)               :: self
    double precision                , intent(in   )               :: x
    double precision                , intent(in   ), dimension(:) :: ya
    double precision                , parameter                   :: rangeTolerance=1.0d-6
    integer         (c_size_t      )                              :: basePoint
    type            (varying_string)                              :: message
    integer         (c_int         )                              :: statusGSL
    double precision                                              :: gradient             , x_
    character       (len=12        )                              :: labelX               , labelX_      , &
         &                                                           labelXMaximum        , labelXMinimum

    call self%assertInterpolatable()
    if (.not.self%initialized) call self%GSLInitialize(ya)
    ! If extrapolation is allowed, check if this is necessary.
    if     (                                                        &
         &   self%extrapolationType == extrapolationTypeExtrapolate &
         &  .and.                                                   &
         &   (                                                      &
         &     x < self%x(1              )                          &
         &    .or.                                                  &
         &     x > self%x(self%countArray)                          &
         &   )                                                      &
         & ) then
       if (x < self%x(1)) then
          basePoint=1_c_size_t
       else
          basePoint=self%countArray
       end if
       statusGSL=gsl_interp_eval_deriv_e(self%gsl_interp,self%x,ya,self%x(basePoint),self%gsl_interp_accel,gradient)
       if (statusGSL /= 0) then
          select case (statusGSL)
          case (GSL_EDom)
             message='requested point is outside of allowed range'
          case default
             message='interpolation failed for unknown reason'
          end select
          call Galacticus_Error_Report(message//{introspection:location})
       end if
       interpolatorInterpolate=ya(basePoint)+gradient*(x-self%x(basePoint))
    else
       ! Allow for rounding errors.
       x_=x
       select case (self%extrapolationType)
       case (extrapolationTypeFix)
          if (x < self%x(1              )                                                                              ) x_=self%x(1              )
          if (x > self%x(self%countArray)                                                                              ) x_=self%x(self%countArray)
       case default
          if (x < self%x(1              ) .and. x > self%x(1              )-rangeTolerance*abs(self%x(1              ))) x_=self%x(1              )
          if (x > self%x(self%countArray) .and. x < self%x(self%countArray)+rangeTolerance*abs(self%x(self%countArray))) x_=self%x(self%countArray)
       end select
       ! Do the interpolation.
       statusGSL=gsl_interp_eval_e(self%gsl_interp,self%x,ya,x_,self%gsl_interp_accel,interpolatorInterpolate)
       if (statusGSL /= GSL_Success) then
          select case (statusGSL)
          case (GSL_EDom)
             write (labelX       ,'(e12.6)')      x
             write (labelX_      ,'(e12.6)')      x_
             write (labelXMinimum,'(e12.6)') self%x (1              )
             write (labelXMaximum,'(e12.6)') self%x (self%countArray)
             message='requested point ['//labelX//' ⟶ '//labelX_//'] is outside of allowed range ['//labelXMinimum//':'//labelXMaximum//']'
          case default
             message='interpolation failed for unknown reason'
          end select
          call Galacticus_Error_Report(message//{introspection:location})
       end if
    end if
    return
  end function interpolatorInterpolate
  
  double precision function interpolatorDerivativeNoYa(self,x)
    !% Interpolate the derivative of the function to {\normalfont \ttfamily x}.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    class           (interpolator  ), intent(inout) :: self
    double precision                , intent(in   ) :: x

    if (allocated(self%y)) then
       interpolatorDerivativeNoYa=self%derivative(x,self%y)
    else
       interpolatorDerivativeNoYa=0.0d0
       call Galacticus_Error_Report("no y() array specified"//{introspection:location})       
    end if
    return
  end function interpolatorDerivativeNoYa
  
  double precision function interpolatorDerivative(self,x,ya)
    !% Interpolate the derivative of the function to {\normalfont \ttfamily x}.
    use            :: Galacticus_Error  , only : Galacticus_Error_Report
    use, intrinsic :: ISO_C_Binding     , only : c_size_t
    use            :: Interface_GSL     , only : GSL_EDom
    use            :: ISO_Varying_String, only : assignment(=)          , operator(//)                , varying_string
    use            :: Table_Labels      , only : extrapolationTypeAbort , extrapolationTypeExtrapolate, extrapolationTypeFix
    implicit none
    class           (interpolator  ), intent(inout)               :: self
    double precision                , intent(in   )               :: x
    double precision                , intent(in   ), dimension(:) :: ya
    type            (varying_string)                              :: message
    integer         (c_int         )                              :: statusGSL
    double precision                                              :: x_

    call self%assertInterpolatable()
    if (.not.self%initialized) call self%GSLInitialize(ya)
    ! If extrapolation is allowed, check if this is necessary.
    x_=x
    select case (self%extrapolationType)
    case (extrapolationTypeExtrapolate,extrapolationTypeFix)
       if (x < self%x(1              )) x_=self%x(1       )
       if (x > self%x(self%countArray)) x_=self%x(self%countArray)
    end select
    ! Do the interpolation.
    statusGSL=gsl_interp_eval_deriv_e(self%gsl_interp,self%x,ya,x_,self%gsl_interp_accel,interpolatorDerivative)
    if (statusGSL /= 0) then
       select case (statusGSL)
       case (GSL_EDom)
          message='requested point is outside of allowed range'
       case default
          message='interpolation failed for unknown reason'
       end select
       call Galacticus_Error_Report(message//{introspection:location})
    end if
    return
  end function interpolatorDerivative
  
  function interpolatorLocate(self,x,closest) result(i)
    !% Locate the element in the table for interpolation of {\normalfont \ttfamily x}.
    use :: Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    integer         (c_size_t    )                          :: i
    class           (interpolator), intent(inout)           :: self
    double precision              , intent(in   )           :: x
    logical                       , intent(in   ), optional :: closest
    !# <optionalArgument name="closest" defaultsTo=".false."/>
    
    ! If array has just one point, always return it.
    if (self%countArray == 1_c_size_t) then
       i=1_c_size_t
       return
    end if
    ! Do the interpolation.
    i=gsl_interp_accel_find(self%gsl_interp_accel,self%x,self%countArray,x)+1_c_size_t
    i=max(min(i,self%countArray-1_c_size_t),1_c_size_t)
    ! If we want the closest point, find it.
    if (closest_ .and. abs(x-self%x(i+1)) < abs(x-self%x(i))) i=i+1_c_size_t
    return
  end function interpolatorLocate

end module Numerical_Interpolation
