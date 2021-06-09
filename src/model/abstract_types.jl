#
# Declare abstract types
#
abstract type IEntity end
abstract type IModification <: IEntity end
abstract type IAppUser <: IEntity end # DEPRECATED, kept because some applications
                                      #  where inheriting from this class
