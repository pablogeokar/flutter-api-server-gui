# flutter_api_gui

## Erros e soluções:

Erro: Building with plugins requires symlink support.

Please enable Developer Mode in your system settings. Run
start ms-settings:developers
to open settings.

Solução:
O problema de compilação ocorre porque o Modo Desenvolvedor não está ativado no Windows, o que é necessário para plugins Flutter. Para resolver:

Abra as Configurações do Windows (Win + I)
Vá para "Atualização e Segurança" > "Para desenvolvedores"
Ative a opção "Modo Desenvolvedor"
Reinicie o computador
Tente compilar novamente com flutter run
Após ativar o Modo Desenvolvedor, a compilação deve funcionar corretamente.
