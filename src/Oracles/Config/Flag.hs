module Oracles.Config.Flag (
    Flag (..), flag, crossCompiling, platformSupportsSharedLibs,
    ghcWithSMP, ghcWithNativeCodeGen, supportsSplitObjects
    ) where

import Base
import Oracles.Config
import Oracles.Config.Setting

data Flag = ArSupportsAtFile
          | CrossCompiling
          | GccIsClang
          | GccLt44
          | GccLt46
          | GhcUnregisterised
          | LeadingUnderscore
          | SolarisBrokenShld
          | SplitObjectsBroken
          | SupportsThisUnitId
          | WithLibdw
          | UseSystemFfi

-- Note, if a flag is set to empty string we treat it as set to NO. This seems
-- fragile, but some flags do behave like this, e.g. GccIsClang.
flag :: Flag -> Action Bool
flag f = do
    let key = case f of
            ArSupportsAtFile   -> "ar-supports-at-file"
            CrossCompiling     -> "cross-compiling"
            GccIsClang         -> "gcc-is-clang"
            GccLt44            -> "gcc-lt-44"
            GccLt46            -> "gcc-lt-46"
            GhcUnregisterised  -> "ghc-unregisterised"
            LeadingUnderscore  -> "leading-underscore"
            SolarisBrokenShld  -> "solaris-broken-shld"
            SplitObjectsBroken -> "split-objects-broken"
            SupportsThisUnitId -> "supports-this-unit-id"
            WithLibdw          -> "with-libdw"
            UseSystemFfi       -> "use-system-ffi"
    value <- unsafeAskConfig key
    when (value `notElem` ["YES", "NO", ""]) . error $ "Configuration flag "
        ++ quote (key ++ " = " ++ value) ++ "cannot be parsed."
    return $ value == "YES"

crossCompiling :: Action Bool
crossCompiling = flag CrossCompiling

platformSupportsSharedLibs :: Action Bool
platformSupportsSharedLibs = do
    badPlatform   <- anyTargetPlatform [ "powerpc-unknown-linux"
                                       , "x86_64-unknown-mingw32"
                                       , "i386-unknown-mingw32" ]
    solaris       <- anyTargetPlatform [ "i386-unknown-solaris2" ]
    solarisBroken <- flag SolarisBrokenShld
    return $ not (badPlatform || solaris && solarisBroken)

ghcWithSMP :: Action Bool
ghcWithSMP = do
    goodArch <- anyTargetArch ["i386", "x86_64", "sparc", "powerpc", "arm"]
    ghcUnreg <- flag GhcUnregisterised
    return $ goodArch && not ghcUnreg

ghcWithNativeCodeGen :: Action Bool
ghcWithNativeCodeGen = do
    goodArch <- anyTargetArch ["i386", "x86_64", "sparc", "powerpc"]
    badOs    <- anyTargetOs ["ios", "aix"]
    ghcUnreg <- flag GhcUnregisterised
    return $ goodArch && not badOs && not ghcUnreg

supportsSplitObjects :: Action Bool
supportsSplitObjects = do
    broken   <- flag SplitObjectsBroken
    ghcUnreg <- flag GhcUnregisterised
    goodArch <- anyTargetArch [ "i386", "x86_64", "powerpc", "sparc" ]
    goodOs   <- anyTargetOs [ "mingw32", "cygwin32", "linux", "darwin", "solaris2"
                            , "freebsd", "dragonfly", "netbsd", "openbsd" ]
    return $ not broken && not ghcUnreg && goodArch && goodOs
