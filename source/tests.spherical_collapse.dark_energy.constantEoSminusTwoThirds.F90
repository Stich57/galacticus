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

!% Contains a program which tests spherical collapse calculations for a dark energy Universe, specifically using a flat,
!% $\omega=-2/3$ cosmology.

program Tests_Spherical_Collapse_Dark_Energy_Omega_Two_Thirds
  !% Tests spherical collapse calculations for a dark energy Universe, specifically using a flat, $\omega=-2/3$
  !% cosmology. Compares results to the fitting function of
  !% \citeauthor{weinberg_constraining_2003}~(\citeyear{weinberg_constraining_2003}; eqn.~18).
  use :: Cosmological_Density_Field, only : criticalOverdensity  , criticalOverdensityClass
  use :: Cosmology_Functions       , only : cosmologyFunctions   , cosmologyFunctionsClass
  use :: Display                   , only : displayVerbositySet  , verbosityLevelStandard
  use :: Events_Hooks              , only : eventsHooksInitialize
  use :: ISO_Varying_String        , only : assignment(=)        , varying_string
  use :: Input_Parameters          , only : inputParameters
  use :: Linear_Growth             , only : linearGrowth         , linearGrowthClass
  use :: Numerical_Constants_Math  , only : Pi
  use :: Unit_Tests                , only : Assert               , Unit_Tests_Begin_Group  , Unit_Tests_End_Group, Unit_Tests_Finish
  implicit none
  double precision                          , dimension(7) :: redshift                 =[0.0d0,1.0d0,3.0d0,7.0d0,15.0d0,31.0d0,63.0d0]
  class           (cosmologyFunctionsClass ), pointer      :: cosmologyFunctions_
  class           (criticalOverdensityClass), pointer      :: criticalOverdensity_
  type            (varying_string          )               :: parameterFile
  character       (len=1024                )               :: message
  integer                                                  :: iExpansion
  double precision                                         :: age                                                                     , alpha                      , &
       &                                                      criticalOverdensityValue                                                , criticalOverdensityExpected, &
       &                                                      expansionFactor                                                         , omega
  type            (inputParameters         )               :: parameters

  ! Set verbosity level.
  call displayVerbositySet(verbosityLevelStandard)
  ! Initialize event hooks.
  call eventsHooksInitialize()

  ! Begin unit tests.
  call Unit_Tests_Begin_Group("Spherical collapse: dark energy solver (ω=-⅔ cosmology)")

  ! Test spherical collapse in a flat universe.
  parameterFile='testSuite/parameters/sphericalCollapse/darkEnergy.constantEoSminusTwoThirds.xml'
  parameters=inputParameters(parameterFile)
  call parameters%markGlobal()
  ! Get the default cosmology functions object.
  cosmologyFunctions_  => cosmologyFunctions ()
  criticalOverdensity_ => criticalOverdensity()
  do iExpansion=1,size(redshift)
     expansionFactor            =cosmologyFunctions_ %expansionFactorFromRedshift(redshift       (iExpansion))
     age                        =cosmologyFunctions_ %cosmicTime                 (expansionFactor            )
     criticalOverdensityValue   =criticalOverdensity_%value                      (age                        )
     omega                      =cosmologyFunctions_ %equationOfStateDarkEnergy  (age                        )
     alpha                      =0.353d0*omega**4+1.044d0*omega**3+1.128d0*omega**2+0.555d0*omega+0.131d0
     criticalOverdensityExpected=(3.0d0*(12.0d0*Pi)**(2.0d0/3.0d0)/20.0d0)*(1.0d0+alpha*log10(cosmologyFunctions_%omegaMatterEpochal(age)))
     write (message,'(a,f6.1,a,f6.4,a)') "critical density for collapse [z=",redshift(iExpansion),";Ωₘ=",cosmologyFunctions_%omegaMatterEpochal(age),"]"
     call Assert(trim(message),criticalOverdensityValue,criticalOverdensityExpected,relTol=1.5d-3)
  end do
  ! End unit tests.
  call Unit_Tests_End_Group()
  call Unit_Tests_Finish   ()
end program Tests_Spherical_Collapse_Dark_Energy_Omega_Two_Thirds
