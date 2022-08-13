# Xlwnya/ShaderStandalone
Shader standalone-ize tools (provided "as is")

## Dependencies
* YamlDotNet https://assetstore.unity.com/packages/tools/integration/yamldotnet-for-unity-36292

## Contents

### bin
* SetGlobal値をデバッグ出力するC#スクリプトを生成するRubyツール等です。
* This is a ruby tool witch generates unity class shows shader global values.
* Usage(Ruby + Git Bash)
```
# grep shader file infos. シェーダファイル内容情報取得。
find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_shaderval.rb > shaderval.txt
find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_shaderprops.rb > shaderprops.txt
find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_include.rb ～/Shaders(*1) > shaderinclude.txt
# *1: include relative base path. include時の相対パスの基準ディレクトリ。
find . -type f -regex '.*\.\(shader\|cginc\)$' -print0 | xargs -n 1024 -0 grep_shaderkeywords.rb > shaderkeywords.txt

# デバッグクラス生成
make_debugclass.rb Debug～ shaderinclude.txt shaderprops.txt shaderval.txt shaderkeywords.txt
# output: Debug～.cs, Debug～.yml, Debug～_forUnity.yml

# Global値をProperties化したシェーダ生成
make_shader_standalone.rb Debug～ Standalone Xlwnya/Standalone/
```

### Scripts
* CheckInuse.cs: MaterialProperty usage checker1(failed). プロパティ使用状況チェック1(失敗)。
* CheckInuseWithMaterial.cs: MaterialProperty usage checker2(failed). プロパティ使用状況チェック2(失敗)。
* MaterialSetGlobal.cs: replace shader and set global value to material tool. シェーダを変更してGlobal値をマテリアルに設定するツール。

## License
とりあえずMIT
