# Build e publicação

Passo a passo para gerar o APK/AAB que vai para o celular ou para a Play Store.

## 1. Assinatura (só precisa ser feita uma vez)

O app é assinado com a chave em `~/.nutriai/upload-keystore.jks` e as senhas em
`android/key.properties` (esse arquivo **não** vai para o Git).

> **Guarde os dois em local seguro** (gerenciador de senhas + backup na nuvem).
> Os dados do diário ficam só no aparelho: se a chave for perdida, não é possível
> publicar uma atualização que instale por cima — o usuário teria que desinstalar
> e perder o histórico.

Se um dia precisar recriar em outra máquina, basta copiar o `.jks` e o
`key.properties` para os mesmos caminhos. Sem o `key.properties`, o Gradle cai
na chave de debug (útil para CI, mas não use esse APK para distribuir).

## 2. Versão

Cada envio precisa de um `versionCode` novo. No `pubspec.yaml`:

```yaml
version: 1.0.0+1   # nome 1.0.0, versionCode 1
```

Ao publicar, suba os dois: `1.0.1+2`, `1.1.0+3` etc.

## 3. Gerar o APK (instalação direta)

```bash
cd /home/joao/programas/nutria
flutter build apk --release
```

Saída: `build/app/outputs/flutter-apk/app-release.apk`.

Para um APK menor (só ARM 64, que é o caso da maioria dos celulares atuais):

```bash
flutter build apk --release --split-per-abi
# build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Conferir a assinatura:

```bash
$ANDROID_HOME/build-tools/36.0.0/apksigner verify --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

### Se o build falhar ao compilar um plugin

Atualizar a versão de um plugin não invalida a pasta `build/<plugin>` (o Gradle
reaproveita cache incremental e pode acusar erros de símbolo que não existem).
Antes de investigar, limpe só o plugin:

```bash
rm -rf build/<plugin>
flutter build apk --release
```

Se o erro citar `Toolchain installation ... does not provide the required
capabilities: [JAVA_COMPILER]`, o Gradle pegou um JRE em vez do JDK 21. Exporte
`JAVA_HOME=/home/joao/.jdks/jdk-21.0.13+9` (ou rode pelo `flutter build`, que já
usa o JDK configurado).

## 4. Instalar no celular

Com o cabo e a depuração USB ligada:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Ou copie o APK para o celular (Drive, Telegram, cabo) e abra o arquivo,
permitindo "instalar apps desconhecidos" para o app de origem.

## 5. Play Store (quando for a hora)

```bash
flutter build appbundle --release
# build/app/outputs/bundle/release/app-release.aab
```

Sobre a assinatura da Play Store: hoje o projeto usa a chave própria (acima).
Se optar por *Play App Signing*, a chave enviada vira a "upload key" — quem
assina de fato é o Google, e a chave local pode ser trocada se perdida.

## 6. Ícones

Tudo é gerado pelo script (não edite PNGs na mão):

```bash
python3 tool/make_icons.py
```

Ele escreve os ícones do Android (legado + adaptativo), iOS, web e o favicon.
O desenho (folha verde sobre creme) está no próprio script.
