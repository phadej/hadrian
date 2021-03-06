module Settings.Builders.GhcCabal (
    ghcCabalBuilderArgs, ghcCabalHsColourBuilderArgs, buildDll0
    ) where

import Context
import Flavour
import Settings.Builders.Common hiding (package)
import Util

ghcCabalBuilderArgs :: Args
ghcCabalBuilderArgs = builder GhcCabal ? do
    verbosity <- expr getVerbosity
    top       <- getTopDirectory
    context   <- getContext
    when (package context /= deriveConstants) $ expr (need inplaceLibCopyTargets)
    mconcat [ arg "configure"
            , arg =<< getPackagePath
            , arg $ top -/- buildPath context
            , dll0Args
            , withStaged $ Ghc CompileHs
            , withStaged (GhcPkg Update)
            , bootPackageDatabaseArgs
            , libraryArgs
            , with HsColour
            , configureArgs
            , packageConstraints
            , withStaged $ Cc CompileC
            , notStage0 ? with Ld
            , withStaged Ar
            , with Alex
            , with Happy
            , verbosity < Chatty ? append [ "-v0", "--configure-option=--quiet"
                , "--configure-option=--disable-option-checking"  ] ]

ghcCabalHsColourBuilderArgs :: Args
ghcCabalHsColourBuilderArgs = builder GhcCabalHsColour ? do
    path    <- getPackagePath
    top     <- getTopDirectory
    context <- getContext
    append [ "hscolour", path, top -/- buildPath context ]

-- TODO: Isn't vanilla always built? If yes, some conditions are redundant.
-- TODO: Need compiler_stage1_CONFIGURE_OPTS += --disable-library-for-ghci?
libraryArgs :: Args
libraryArgs = do
    ways     <- getLibraryWays
    withGhci <- expr ghcWithInterpreter
    append [ if vanilla `elem` ways
             then  "--enable-library-vanilla"
             else "--disable-library-vanilla"
           , if vanilla `elem` ways && withGhci && not (dynamicGhcPrograms flavour)
             then  "--enable-library-for-ghci"
             else "--disable-library-for-ghci"
           , if profiling `elem` ways
             then  "--enable-library-profiling"
             else "--disable-library-profiling"
           , if dynamic `elem` ways
             then  "--enable-shared"
             else "--disable-shared" ]

-- TODO: LD_OPTS?
configureArgs :: Args
configureArgs = do
    top <- getTopDirectory
    let conf key expr = do
            values <- unwords <$> expr
            not (null values) ?
                arg ("--configure-option=" ++ key ++ "=" ++ values)
        cFlags   = mconcat [ remove ["-Werror"] cArgs
                           , argStagedSettingList ConfCcArgs
                           , arg $ "-I" ++ top -/- generatedPath ]
        ldFlags  = ldArgs  <> (argStagedSettingList ConfGccLinkerArgs)
        cppFlags = cppArgs <> (argStagedSettingList ConfCppArgs)
    cldFlags <- unwords <$> (cFlags <> ldFlags)
    mconcat
        [ conf "CFLAGS"   cFlags
        , conf "LDFLAGS"  ldFlags
        , conf "CPPFLAGS" cppFlags
        , not (null cldFlags) ? arg ("--gcc-options=" ++ cldFlags)
        , conf "--with-iconv-includes"    $ return <$> getSetting IconvIncludeDir
        , conf "--with-iconv-libraries"   $ return <$> getSetting IconvLibDir
        , conf "--with-gmp-includes"      $ return <$> getSetting GmpIncludeDir
        , conf "--with-gmp-libraries"     $ return <$> getSetting GmpLibDir
        , conf "--with-curses-libraries"  $ return <$> getSetting CursesLibDir
        , crossCompiling ? (conf "--host" $ return <$> getSetting TargetPlatformFull)
        , conf "--with-cc" $ argStagedBuilderPath (Cc CompileC) ]

packageConstraints :: Args
packageConstraints = stage0 ? do
    constraints <- expr . readFileLines $ bootPackageConstraints
    append $ concat [ ["--constraint", c] | c <- constraints ]

cppArgs :: Args
cppArgs = arg $ "-I" ++ generatedPath

withBuilderKey :: Builder -> String
withBuilderKey b = case b of
    Ar _       -> "--with-ar="
    Ld         -> "--with-ld="
    Cc  _ _    -> "--with-gcc="
    Ghc _ _    -> "--with-ghc="
    Alex       -> "--with-alex="
    Happy      -> "--with-happy="
    GhcPkg _ _ -> "--with-ghc-pkg="
    HsColour   -> "--with-hscolour="
    _          -> error $ "withBuilderKey: not supported builder " ++ show b

-- Expression 'with Alex' appends "--with-alex=/path/to/alex" and needs Alex.
with :: Builder -> Args
with b = isSpecified b ? do
    top  <- getTopDirectory
    path <- getBuilderPath b
    expr $ needBuilder b
    arg $ withBuilderKey b ++ unifyPath (top </> path)

withStaged :: (Stage -> Builder) -> Args
withStaged sb = with . sb =<< getStage

buildDll0 :: Context -> Action Bool
buildDll0 Context {..} = do
    windows <- windowsHost
    return $ windows && stage == Stage1 && package == compiler

-- This is a positional argument, hence:
-- * if it is empty, we need to emit one empty string argument;
-- * otherwise, we must collapse it into one space-separated string.
dll0Args :: Args
dll0Args = do
    context  <- getContext
    dll0     <- expr $ buildDll0 context
    withGhci <- expr ghcWithInterpreter
    arg . unwords . concat $ [ modules     | dll0             ]
                          ++ [ ghciModules | dll0 && withGhci ] -- see #9552
  where
    modules = [ "Annotations"
              , "ApiAnnotation"
              , "Avail"
              , "Bag"
              , "BasicTypes"
              , "Binary"
              , "BooleanFormula"
              , "BreakArray"
              , "BufWrite"
              , "Class"
              , "CmdLineParser"
              , "CmmType"
              , "CoAxiom"
              , "ConLike"
              , "Coercion"
              , "Config"
              , "Constants"
              , "CoreArity"
              , "CoreFVs"
              , "CoreSubst"
              , "CoreSyn"
              , "CoreTidy"
              , "CoreUnfold"
              , "CoreUtils"
              , "CoreSeq"
              , "CoreStats"
              , "CostCentre"
              , "Ctype"
              , "DataCon"
              , "Demand"
              , "Digraph"
              , "DriverPhases"
              , "DynFlags"
              , "Encoding"
              , "ErrUtils"
              , "Exception"
              , "ExtsCompat46"
              , "FamInstEnv"
              , "FastFunctions"
              , "FastMutInt"
              , "FastString"
              , "FastTypes"
              , "Fingerprint"
              , "FiniteMap"
              , "ForeignCall"
              , "Hooks"
              , "HsBinds"
              , "HsDecls"
              , "HsDoc"
              , "HsExpr"
              , "HsImpExp"
              , "HsLit"
              , "PlaceHolder"
              , "HsPat"
              , "HsSyn"
              , "HsTypes"
              , "HsUtils"
              , "HscTypes"
              , "IOEnv"
              , "Id"
              , "IdInfo"
              , "IfaceSyn"
              , "IfaceType"
              , "InstEnv"
              , "Kind"
              , "Lexeme"
              , "Lexer"
              , "ListSetOps"
              , "Literal"
              , "Maybes"
              , "MkCore"
              , "MkId"
              , "Module"
              , "MonadUtils"
              , "Name"
              , "NameEnv"
              , "NameSet"
              , "OccName"
              , "OccurAnal"
              , "OptCoercion"
              , "OrdList"
              , "Outputable"
              , "PackageConfig"
              , "Packages"
              , "Pair"
              , "Panic"
              , "PatSyn"
              , "PipelineMonad"
              , "Platform"
              , "PlatformConstants"
              , "PprCore"
              , "PrelNames"
              , "PrelRules"
              , "Pretty"
              , "PrimOp"
              , "RdrName"
              , "Rules"
              , "Serialized"
              , "SrcLoc"
              , "StaticFlags"
              , "StringBuffer"
              , "TcEvidence"
              , "TcRnTypes"
              , "TcType"
              , "TrieMap"
              , "TyCon"
              , "Type"
              , "TypeRep"
              , "TysPrim"
              , "TysWiredIn"
              , "Unify"
              , "UniqFM"
              , "UniqSet"
              , "UniqSupply"
              , "Unique"
              , "Util"
              , "Var"
              , "VarEnv"
              , "VarSet" ]
    ghciModules = [ "Bitmap"
                  , "BlockId"
                  , "ByteCodeAsm"
                  , "ByteCodeInstr"
                  , "ByteCodeItbls"
                  , "CLabel"
                  , "Cmm"
                  , "CmmCallConv"
                  , "CmmExpr"
                  , "CmmInfo"
                  , "CmmMachOp"
                  , "CmmNode"
                  , "CmmSwitch"
                  , "CmmUtils"
                  , "CodeGen.Platform"
                  , "CodeGen.Platform.ARM"
                  , "CodeGen.Platform.ARM64"
                  , "CodeGen.Platform.NoRegs"
                  , "CodeGen.Platform.PPC"
                  , "CodeGen.Platform.PPC_Darwin"
                  , "CodeGen.Platform.SPARC"
                  , "CodeGen.Platform.X86"
                  , "CodeGen.Platform.X86_64"
                  , "FastBool"
                  , "InteractiveEvalTypes"
                  , "MkGraph"
                  , "PprCmm"
                  , "PprCmmDecl"
                  , "PprCmmExpr"
                  , "Reg"
                  , "RegClass"
                  , "SMRep"
                  , "StgCmmArgRep"
                  , "StgCmmClosure"
                  , "StgCmmEnv"
                  , "StgCmmLayout"
                  , "StgCmmMonad"
                  , "StgCmmProf"
                  , "StgCmmTicky"
                  , "StgCmmUtils"
                  , "StgSyn"
                  , "Stream" ]
