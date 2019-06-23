!! Copyright 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018,
!!           2019
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

!% Contains a module which implements a multi output property extractor class.

  type, public :: multiExtractorList
     class(nodePropertyExtractorClass), pointer :: extractor_
     type (multiExtractorList        ), pointer :: next       => null()
  end type multiExtractorList
  
  !# <nodePropertyExtractor name="nodePropertyExtractorMulti">
  !#  <description>A multi output extractor property extractor class.</description>
  !# </nodePropertyExtractor>
  type, extends(nodePropertyExtractorTuple) :: nodePropertyExtractorMulti
     !% A multi property extractor output extractor class, which concatenates properties from any number of other property
     !% extractors.
     private
     type(multiExtractorList), pointer :: extractors => null()
   contains
     !@ <objectMethods>
     !@  <object>nodePropertyExtractorMulti</object>
     !@  <objectMethod>
     !@   <method>initialize</method>
     !@   <description>Initialize the multi property extractor.</description>
     !@   <type>\void</type>
     !@   <pass>yes</pass>
     !@   <arguments></arguments>
     !@  </objectMethod>
     !@ </objectMethods>
     final     ::                 multiDestructor
     procedure :: elementCount => multiElementCount
     procedure :: extract      => multiExtract
     procedure :: names        => multiNames
     procedure :: descriptions => multiDescriptions
     procedure :: unitsInSI    => multiUnitsInSI
     procedure :: addInstances => multiAddInstances
     procedure :: type         => multiType
     procedure :: deepCopy     => multiDeepCopy
  end type nodePropertyExtractorMulti

  interface nodePropertyExtractorMulti
     !% Constructors for the ``multi'' output extractor class.
     module procedure multiConstructorParameters
     module procedure multiConstructorInternal
  end interface nodePropertyExtractorMulti

contains

  function multiConstructorParameters(parameters) result(self)
    !% Constructor for the ``multi'' output extractor property extractor class which takes a parameter set as input.
    use Input_Parameters
    implicit none
    type   (nodePropertyExtractorMulti)                :: self
    type   (inputParameters           ), intent(inout) :: parameters
    type   (multiExtractorList        ), pointer       :: extractor_
    integer                                            :: i

    self      %extractors => null()
    extractor_            => null()
    do i=1,parameters%copiesCount('nodePropertyExtractorMethod',zeroIfNotPresent=.true.)
       if (associated(extractor_)) then
          allocate(extractor_%next)
          extractor_ => extractor_%next
       else
          allocate(self%extractors)
          extractor_ => self%extractors
       end if
       !# <objectBuilder class="nodePropertyExtractor" name="extractor_%extractor_" source="parameters" copy="i" />
    end do
    return
  end function multiConstructorParameters

  function multiConstructorInternal(extractors) result(self)
    !% Internal constructor for the ``multi'' output extractor property extractor class.
    implicit none
    type(nodePropertyExtractorMulti)                         :: self
    type(multiExtractorList        ), target , intent(in   ) :: extractors
    type(multiExtractorList        ), pointer                :: extractor_

    self      %extractors => extractors
    extractor_            => extractors
    do while (associated(extractor_))
       !# <referenceCountIncrement owner="extractor_" object="extractor_"/>
       extractor_ => extractor_%next
    end do
    return
  end function multiConstructorInternal

  subroutine multiDestructor(self)
    !% Destructor for the {\normalfont \ttfamily multi} output extractor property extractor class.
    implicit none
    type(nodePropertyExtractorMulti), intent(inout) :: self
    type(multiExtractorList        ), pointer       :: extractor_, extractorNext
    
    if (associated(self%extractors)) then
       extractor_ => self%extractors
       do while (associated(extractor_))
          extractorNext => extractor_%next
          !# <objectDestructor name="extractor_%extractor_"/>
          deallocate(extractor_)
          extractor_ => extractorNext
       end do
    end if
    return
  end subroutine multiDestructor
  
  integer function multiElementCount(self,time)
    !% Return the number of elements in the multiple property extractors.
    use Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    class           (nodePropertyExtractorMulti), intent(inout) :: self
    double precision                            , intent(in   ) :: time
    type            (multiExtractorList        ), pointer       :: extractor_

    multiElementCount =  0
    extractor_        => self%extractors
    do while (associated(extractor_))
       multiElementCount=multiElementCount+1
       select type (extractor_ => extractor_%extractor_)
       class is (nodePropertyExtractorScalar)
          multiElementCount=multiElementCount+1
       class is (nodePropertyExtractorTuple )
          multiElementCount=multiElementCount+extractor_%elementCount(time)
       class default
          call Galacticus_Error_Report('unsupported property extractor type'//{introspection:location})
       end select
       extractor_ => extractor_%next
    end do
    return
  end function multiElementCount

  function multiExtract(self,node,time,instance)
    !% Implement a multi output extractor.
    use Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    double precision                            , dimension(:) , allocatable :: multiExtract
    class           (nodePropertyExtractorMulti), intent(inout)              :: self
    type            (treeNode                  ), intent(inout)              :: node
    double precision                            , intent(in   )              :: time
    type            (multiCounter              ), intent(inout), optional    :: instance
    type            (multiExtractorList        ), pointer                    :: extractor_
    integer                                                                  :: offset      , elementCount

    allocate(multiExtract(self%elementCount(time)))
    offset     =  0
    extractor_ => self%extractors
    do while (associated(extractor_))
       select type (extractor_ => extractor_%extractor_)
       class is (nodePropertyExtractorScalar)
          elementCount=1
          multiExtract(offset+1:offset+elementCount)=extractor_%extract(node     ,instance)
       class is (nodePropertyExtractorTuple )
          elementCount=extractor_%elementCount(time)
          multiExtract(offset+1:offset+elementCount)=extractor_%extract(node,time,instance)
       class default
          elementCount=0
          call Galacticus_Error_Report('unsupported property extractor type'//{introspection:location})
       end select
       offset     =  offset         +elementCount
       extractor_ => extractor_%next
    end do
    return
  end function multiExtract

  subroutine multiAddInstances(self,node,instance)
    !% Implement adding of instances to a multi output extractor.
    implicit none
    class(nodePropertyExtractorMulti), intent(inout) :: self
    type (treeNode                  ), intent(inout) :: node
    type (multiCounter              ), intent(inout) :: instance
    type (multiExtractorList        ), pointer       :: extractor_

    extractor_ => self%extractors
    do while (associated(extractor_))
       call extractor_%extractor_%addInstances(node,instance)
       extractor_ => extractor_%next
    end do
    return
  end subroutine multiAddInstances

  function multiNames(self,time)
    !% Return the names of the multiple properties.
    use Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    type            (varying_string            ), dimension(:) , allocatable :: multiNames
    class           (nodePropertyExtractorMulti), intent(inout)              :: self
    double precision                            , intent(in   )              :: time
    type            (multiExtractorList        ), pointer                    :: extractor_
    integer                                                                  :: offset    , elementCount

    allocate(multiNames(self%elementCount(time)))
    offset     =  0
    extractor_ => self%extractors
    do while (associated(extractor_))
       select type (extractor_ => extractor_%extractor_)
       class is (nodePropertyExtractorScalar)
          elementCount=1
          multiNames(offset+1:offset+elementCount)=extractor_%name (    )
       class is (nodePropertyExtractorTuple )
          elementCount=extractor_%elementCount(time)
          multiNames(offset+1:offset+elementCount)=extractor_%names(time)
       class default
          elementCount=0
          call Galacticus_Error_Report('unsupported property extractor type'//{introspection:location})
       end select
       offset     =  offset         +elementCount
       extractor_ => extractor_%next
    end do
    return
  end function multiNames

  function multiDescriptions(self,time)
    !% Return the descriptions of the multiple properties.
    use Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    type            (varying_string            ), dimension(:) , allocatable :: multiDescriptions
    class           (nodePropertyExtractorMulti), intent(inout)              :: self
    double precision                            , intent(in   )              :: time
    type            (multiExtractorList        ), pointer                    :: extractor_
    integer                                                                  :: offset           , elementCount

    allocate(multiDescriptions(self%elementCount(time)))
    offset     =  0
    extractor_ => self%extractors
    do while (associated(extractor_))
       select type (extractor_ => extractor_%extractor_)
       class is (nodePropertyExtractorScalar)
          elementCount=1
          multiDescriptions(offset+1:offset+elementCount)=extractor_%description (    )
       class is (nodePropertyExtractorTuple )
          elementCount=extractor_%elementCount(time)
          multiDescriptions(offset+1:offset+elementCount)=extractor_%descriptions(time)
       class default
          elementCount=0
          call Galacticus_Error_Report('unsupported property extractor type'//{introspection:location})
       end select
       offset     =  offset         +elementCount
       extractor_ => extractor_%next
    end do
    return
  end function multiDescriptions

  function multiUnitsInSI(self,time)
    !% Return the units of the multiple properties in the SI system.
    use Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    double precision                            , dimension(:) , allocatable :: multiUnitsInSI
    class           (nodePropertyExtractorMulti), intent(inout)              :: self
    double precision                            , intent(in   )              :: time
    type            (multiExtractorList        ), pointer                    :: extractor_
    integer                                                                  :: offset        , elementCount

    allocate(multiUnitsInSI(self%elementCount(time)))
    offset     =  0
    extractor_ => self%extractors
    do while (associated(extractor_))
       select type (extractor_ => extractor_%extractor_)
          class is (nodePropertyExtractorScalar)
          elementCount=1
          multiUnitsInSI(offset+1:offset+elementCount)=extractor_%unitsInSI(    )
       class is (nodePropertyExtractorTuple )
          elementCount=extractor_%elementCount(time)
          multiUnitsInSI(offset+1:offset+elementCount)=extractor_%unitsInSI(time)
       class default
          elementCount=0
          call Galacticus_Error_Report('unsupported property extractor type'//{introspection:location})
       end select
       offset     =  offset         +elementCount
       extractor_ => extractor_%next
    end do
    return
  end function multiUnitsInSI

  integer function multiType(self)
    !% Return the type of the multi property.
    use Output_Analyses_Options, only : outputAnalysisPropertyTypeLinear
    implicit none
    class(nodePropertyExtractorMulti), intent(inout) :: self
    !GCC$ attributes unused :: self

    multiType=outputAnalysisPropertyTypeLinear
    return
  end function multiType

  subroutine multiDeepCopy(self,destination)
    !% Perform a deep copy for the {\normalfont \ttfamily multi} extractor class.
    use Galacticus_Error, only : Galacticus_Error_Report
    implicit none
    class(nodePropertyExtractorMulti), intent(inout) :: self
    class(nodePropertyExtractorClass), intent(inout) :: destination
    type (multiExtractorList        ), pointer       :: extractor_   , extractorDestination_, &
         &                                              extractorNew_

    call self%nodePropertyExtractorClass%deepCopy(destination)
    select type (destination)
    type is (nodePropertyExtractorMulti)
       ! Copy list of extractors.       
       destination%extractors => null           ()
       extractorDestination_  => null           ()
       extractor_             => self%extractors
       do while (associated(extractor_))
          allocate(extractorNew_)
          if (associated(extractorDestination_)) then
             extractorDestination_%next       => extractorNew_
             extractorDestination_            => extractorNew_             
          else
             destination          %extractors => extractorNew_
             extractorDestination_            => extractorNew_
          end if
          allocate(extractorNew_%extractor_,mold=extractor_%extractor_)
          !# <deepCopy source="extractor_%extractor_" destination="extractorNew_%extractor_"/>
          extractor_ => extractor_%next
       end do
       class default
       call Galacticus_Error_Report('destination and source types do not match'//{introspection:location})
    end select
    return
  end subroutine multiDeepCopy