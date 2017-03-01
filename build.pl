use Cwd;
use Cwd 'abs_path';
use File::Basename;
use File::Path;
use File::Copy;

my $buildsroot = "./builds";
my $buildMachine = $ENV{UNITY_THISISABUILDMACHINE};
my $msbuildPath = "C:\\Program Files (x86)\\MSBuild\\14.0\\Bin\\MSBuild.exe";

if (!(-f "$msbuildPath"))
{
	die("Unable to locate msbuild at : $msbuildPath\n");
}

my $usBuildDir = "./build";
	
if (!(-d "$usBuildDir"))
{
	rmtree($usBuildDir);
}

mkdir($usBuildDir);

BuildUnityScriptFor45();

sub MSBuild
{
	print(">>> Running : $msbuildPath @_\n");
	system("$msbuildPath", @_) eq 0 or die("Failed to msbuild @_\n");
}

sub Booc45
{
	my $commandLine = shift;
	
	system("$usBuildDir/booc -debug- $commandLine") eq 0 or die("booc failed to execute: $usBuildDir/booc -debug- $commandLine\n");
}

sub GitClone
{
	my $repo = shift;
	my $localFolder = shift;
	my $branch = shift;
	$branch = defined($branch)?$branch:"master";

	if (-d $localFolder) {
		return;
	}
	print "running git clone --branch $branch $repo $localFolder\n";
	system("git clone --branch $branch $repo $localFolder") eq 0 or die("git clone $repo $localFolder failed!");
}

sub BuildUnityScriptFor45
{
	my $booCheckout = "./boo/build";
	
	# Build host is handling this
	if (!$buildMachine)
	{
		if (!(-d "$booCheckout"))
		{
			print(">>> Checking out boo\n");
			GitClone("git://github.com/Unity-Technologies/boo.git", $booCheckout, "unity-trunk");
		}
	}
		
	my $boocCsproj = "$booCheckout/src/booc/booc.csproj";
	if (!(-f "$boocCsproj"))
	{
		die("Unable to locate : $boocCsproj\n");
	}
	
	MSBuild("$boocCsproj", "/t:Rebuild");
	
	foreach my $file (glob "$booCheckout/ide-build/Boo.Lang*.dll")
	{
		print(">>> Copying $file to $usBuildDir\n");
		copy($file, "$usBuildDir/.");
	}
	
	copy("$booCheckout/ide-build/booc.exe", "$usBuildDir/.");
	
	Booc45("-out:$usBuildDir/Boo.Lang.Extensions.dll -noconfig -nostdlib -srcdir:$booCheckout/src/Boo.Lang.Extensions -r:System.dll -r:System.Core.dll -r:mscorlib.dll -r:Boo.Lang.dll -r:Boo.Lang.Compiler.dll");
	Booc45("-out:$usBuildDir/Boo.Lang.Useful.dll -srcdir:$booCheckout/src/Boo.Lang.Useful -r:Boo.Lang.Parser");
	Booc45("-out:$usBuildDir/Boo.Lang.PatternMatching.dll -srcdir:$booCheckout/src/Boo.Lang.PatternMatching");
	
	my $UnityScriptLangDLL = "$usBuildDir/UnityScript.Lang.dll";
	Booc45("-out:$UnityScriptLangDLL -srcdir:./src/UnityScript.Lang");
	
	my $UnityScriptDLL = "$usBuildDir/UnityScript.dll";
	Booc45("-out:$UnityScriptDLL -srcdir:./src/UnityScript -r:$UnityScriptLangDLL -r:Boo.Lang.Parser.dll -r:Boo.Lang.PatternMatching.dll");
	Booc45("-out:$usBuildDir/us.exe -srcdir:./src/us -r:$UnityScriptLangDLL -r:$UnityScriptDLL -r:Boo.Lang.Useful.dll");
	
	# # unityscript test suite
	# my $UnityScriptTestsCSharpDLL = "./src/UnityScript.Tests.CSharp/bin/Debug/UnityScript.Tests.CSharp.dll";
	# MSBuild("./src/UnityScript.Tests.CSharp/UnityScript.Tests.CSharp.csproj", "/t:Rebuild");
		
	# my $UnityScriptTestsDLL = <$usBuildDir/UnityScript.Tests.dll>;
	# Booc("-out:$UnityScriptTestsDLL -srcdir:./src/UnityScript.Tests -r:$UnityScriptLangDLL -r:$UnityScriptDLL -r:$UnityScriptTestsCSharpDLL -r:Boo.Lang.Compiler.dll -r:Boo.Lang.Useful.dll");
	# cp("$UnityScriptTestsCSharpDLL $usBuildDir/");

	system("7z a -tzip -r $usBuildDir/builds.zip $usBuildDir/*")
}