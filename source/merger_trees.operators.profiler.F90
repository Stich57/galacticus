!! Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017
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

  !% Contains a module which implements a merger tree operator which profiles tree structure.
  
  use Kind_Numbers

  !# <mergerTreeOperator name="mergerTreeOperatorProfiler" defaultThreadPrivate="yes">
  !#  <description>
  !#   A merger tree operator which profiles merger tree structure.
  !# </description>
  !# </mergerTreeOperator>
  type, extends(mergerTreeOperatorClass) :: mergerTreeOperatorProfiler
     !% A merger tree operator class which profiles merger tree structure.
     private
     integer         (kind_int8)                              :: nodeCount                  , singleProgenitorCount
     integer         (kind_int8), allocatable, dimension(:,:) :: nonPrimaryProgenitorCount
     integer                                                  :: massBinsCount              , timeBinsCount
     double precision           , allocatable, dimension(:  ) :: mass                       , time
     double precision                                         :: massMinimumLogarithmic     , timeMinimumLogarithmic     , &
          &                                                      massLogarithmicDeltaInverse, timeLogarithmicDeltaInverse
   contains
     procedure :: operate  => profilerOperate
     procedure :: finalize => profilerFinalize
  end type mergerTreeOperatorProfiler
  
  interface mergerTreeOperatorProfiler
     !% Constructors for the prune-hierarchy merger tree operator class.
     module procedure profilerConstructorParameters
     module procedure profilerConstructorInternal
  end interface mergerTreeOperatorProfiler

contains

  function profilerConstructorParameters(parameters) result(self)
    !% Constructor for the information content merger tree operator class which takes a parameter set as input.
    use Input_Parameters2
    implicit none
    type            (mergerTreeOperatorProfiler)                :: self
    type            (inputParameters           ), intent(inout) :: parameters
    double precision                                            :: massMinimum      , massMaximum      , &
         &                                                         redshiftMinimum  , redshiftMaximum
    integer                                                     :: massBinsPerDecade, timeBinsPerDecade
    !# <inputParameterList label="allowedParameterNames" />

    call parameters%checkParameters(allowedParameterNames)
    !# <inputParameter>
    !#   <name>massMinimum</name>
    !#   <source>parameters</source>
    !#   <defaultValue>1.0d10</defaultValue>
    !#   <description>The minimum mass of non-primary progenitor to count.</description>
    !#   <type>real</type>
    !#   <cardinality>1</cardinality>
    !# </inputParameter>
    !# <inputParameter>
    !#   <name>massMaximum</name>
    !#   <source>parameters</source>
    !#   <defaultValue>1.0d15</defaultValue>
    !#   <description>The maximum mass of non-primary progenitor to count.</description>
    !#   <type>real</type>
    !#   <cardinality>1</cardinality>
    !# </inputParameter>
    !# <inputParameter>
    !#   <name>massBinsPerDecade</name>
    !#   <source>parameters</source>
    !#   <defaultValue>10</defaultValue>
    !#   <description>The number of bins per decade of non-primary progenitor mass.</description>
    !#   <type>integer</type>
    !#   <cardinality>1</cardinality>
    !# </inputParameter>
    !# <inputParameter>
    !#   <name>redshiftMinimum</name>
    !#   <source>parameters</source>
    !#   <defaultValue>0.0d0</defaultValue>
    !#   <description>The minimum redshift at which to count non-primary progenitors.</description>
    !#   <type>real</type>
    !#   <cardinality>1</cardinality>
    !# </inputParameter>
    !# <inputParameter>
    !#   <name>redshiftMaximum</name>
    !#   <source>parameters</source>
    !#   <defaultValue>10.0d0</defaultValue>
    !#   <description>The maximum redshift at which to count non-primary progenitors.</description>
    !#   <type>real</type>
    !#   <cardinality>1</cardinality>
    !# </inputParameter>
    !# <inputParameter>
    !#   <name>timeBinsPerDecade</name>
    !#   <source>parameters</source>
    !#   <defaultValue>10</defaultValue>
    !#   <description>The number of bins per decade of time at which to count non-primary progenitors.</description>
    !#   <type>integer</type>
    !#   <cardinality>1</cardinality>
    !# </inputParameter>
    self=mergerTreeOperatorProfiler(massMinimum,massMaximum,massBinsPerDecade,redshiftMinimum,redshiftMaximum,timeBinsPerDecade)
    return
  end function profilerConstructorParameters
  
  function profilerConstructorInternal(massMinimum,massMaximum,massBinsPerDecade,redshiftMinimum,redshiftMaximum,timeBinsPerDecade) result(self)
    !% Internal constructor for the information content merger tree operator class.
    use Numerical_Ranges
    use Cosmology_Functions
    use Memory_Management
    implicit none
    type            (mergerTreeOperatorProfiler)                :: self
    double precision                            , intent(in   ) :: massMinimum        , massMaximum      , &
         &                                                         redshiftMinimum    , redshiftMaximum
    integer                                     , intent(in   ) :: massBinsPerDecade  , timeBinsPerDecade
    class           (cosmologyFunctionsClass   ), pointer       :: cosmologyFunctions_
    double precision                                            :: timeMinimum        , timeMaximum
    
    ! Construct bins in mass and time.
    cosmologyFunctions_             => cosmologyFunctions()
    timeMinimum                     =  cosmologyFunctions_%cosmicTime(cosmologyFunctions_%expansionFactorFromRedshift(redshiftMaximum))
    timeMaximum                     =  cosmologyFunctions_%cosmicTime(cosmologyFunctions_%expansionFactorFromRedshift(redshiftMinimum))
    self%massBinsCount              =  int(dble(massBinsPerDecade)*log10(massMaximum/massMinimum))+1
    self%timeBinsCount              =  int(dble(timeBinsPerDecade)*log10(timeMaximum/timeMinimum))+1
    self%mass                       =  Make_Range(massMinimum,massMaximum,self%massBinsCount,rangeType=rangeTypeLogarithmic,rangeBinned=.true.)
    self%time                       =  Make_Range(timeMinimum,timeMaximum,self%timeBinsCount,rangeType=rangeTypeLogarithmic,rangeBinned=.true.)
    self%massMinimumLogarithmic     =  log10(massMinimum)
    self%timeMinimumLogarithmic     =  log10(timeMinimum)
    self%massLogarithmicDeltaInverse=  dble(self%massBinsCount)/log10(massMaximum/massMinimum)
    self%timeLogarithmicDeltaInverse=  dble(self%timeBinsCount)/log10(timeMaximum/timeMinimum)
    ! Allocate bins.
    call allocateArray(self%nonPrimaryProgenitorCount,[self%massBinsCount,self%timeBinsCount])
    ! Initialize counts.
    self%nodeCount                =0_kind_int8
    self%singleProgenitorCount    =0_kind_int8
    self%nonPrimaryProgenitorCount=0_kind_int8
    return
  end function profilerConstructorInternal

  subroutine profilerOperate(self,tree)
    !% Perform a information content operation on a merger tree.
    implicit none
    class  (mergerTreeOperatorProfiler), intent(inout)          :: self
    type   (mergerTree                ), intent(inout), target  :: tree
    type   (mergerTree                )               , pointer :: treeCurrent
    type   (treeNode                  )               , pointer :: node
    class  (nodeComponentBasic        )               , pointer :: basic
    integer                                                     :: massIndex  , timeIndex

     ! Iterate over trees.
     treeCurrent => tree
     do while (associated(treeCurrent))
        ! Walk the tree.
        node => treeCurrent%baseNode
        do while (associated(node))
           ! Count nodes.
           self%nodeCount=self%nodeCount+1_kind_int8
           ! Check for single progenitor nodes.
           if (associated(node%firstChild)) then
              if (associated(node%firstChild%sibling)) then
                ! Count non-primary progenitors as a function of mass and epoch.
                basic     => node%basic()
                massIndex =  int((log10(basic%mass())-self%massMinimumLogarithmic)*self%massLogarithmicDeltaInverse)+1
                timeIndex =  int((log10(basic%time())-self%timeMinimumLogarithmic)*self%timeLogarithmicDeltaInverse)+1
                if     (                                                     &
                     &   massIndex > 0 .and. massIndex <= self%massBinsCount &
                     &  .and.                                                &
                     &   timeIndex > 0 .and. timeIndex <= self%timeBinsCount &
                     & ) self%nonPrimaryProgenitorCount(massIndex,timeIndex)=self%nonPrimaryProgenitorCount(massIndex,timeIndex)+1_kind_int8         
             else
                ! Check for single progenitor nodes.
                self%singleProgenitorCount=self%singleProgenitorCount+1_kind_int8
              end if
           end if
           ! Walk to the next node in the tree.
           node => node%walkTree()
        end do
        ! Move to the next tree.
        treeCurrent => treeCurrent%nextTree
     end do
    return
  end subroutine profilerOperate

  subroutine profilerFinalize(self)
    !% Outputs tree information content function.
    use IO_HDF5
    use Galacticus_HDF5
    implicit none
    class  (mergerTreeOperatorProfiler), intent(inout)               :: self
    type   (hdf5Object                )                              :: profilerGroup
    integer(kind_int8                 )                              :: nodeCountCurrent                , singleProgenitorCountCurrent
    integer(kind_int8                 ), dimension(:,:), allocatable :: nonPrimaryProgenitorCountCurrent
    
    !$omp critical(HDF5_Access)
    ! Output information content information.
    profilerGroup=galacticusOutputFile%openGroup('treeProfiler','Profiling information on merger trees.',objectsOverwritable=.true.,overwriteOverride=.true.)
    if (profilerGroup%hasAttribute('nodeCount'                )) then
       call profilerGroup%readAttribute('nodeCount'              ,nodeCountCurrent                  )
       self%nodeCount                =self%nodeCount                +nodeCountCurrent
    end if
    if (profilerGroup%hasAttribute('singleProgenitorCount'    )) then
       call profilerGroup%readAttribute('singleProgenitorCount'   ,singleProgenitorCountCurrent     )
       self%singleProgenitorCount    =self%singleProgenitorCount    +singleProgenitorCountCurrent
    end if
   if (profilerGroup%hasDataset   ('nonPrimaryProgenitorCount')) then
       call profilerGroup%readDataset  ('nonPrimaryProgenitorCount',nonPrimaryProgenitorCountCurrent)
       self%nonPrimaryProgenitorCount=self%nonPrimaryProgenitorCount+nonPrimaryProgenitorCountCurrent
    end if
    call profilerGroup%writeAttribute(self%nodeCount                ,'nodeCount'                )
    call profilerGroup%writeAttribute(self%singleProgenitorCount    ,'singleProgenitorCount'    )
    call profilerGroup%writeDataset  (self%nonPrimaryProgenitorCount,'nonPrimaryProgenitorCount')
    call profilerGroup%writeDataset  (self%mass                     ,'nonPrimaryProgenitorMass' )
    call profilerGroup%writeDataset  (self%time                     ,'nonPrimaryProgenitorTime' )
    call profilerGroup%close         (                                                          )
    !$omp end critical(HDF5_Access)
    return
  end subroutine profilerFinalize