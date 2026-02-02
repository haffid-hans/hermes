#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

RESET='\033[0m'
BOLD='\033[1m'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
LIGHT_GREEN='\033[1;32m'

declare -A dotFiles
declare -A configFiles
declare -A projectLangFiles
declare -A frameworkFiles

info()    { echo -e "${MAGENTA}ℹ${RESET} $*"; }
success() { echo -e "${GREEN}✔${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✘${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}== $* ==${RESET}"; }

normalize() {
    tr '[:upper:]' '[:lower:]' <<< "$1"
}

json_escape() {
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r/\\r/g' -e 's/\n/\\n/g'
}

json_from_assoc() {
    local -n assoc="$1"
    local first=1
    echo "{"
    for key in "${!assoc[@]}"; do
        (( first )) || echo ","
        first=0
        printf '  "%s": "%s"' \
            "$(printf '%s' "$key" | json_escape)" \
            "$(printf '%s' "${assoc[$key]}" | json_escape)"
    done
    echo
    echo "}"
}

json_from_frameworks() {
    local first_file=1
    echo "{"
    for file in "${!frameworkFiles[@]}"; do
        (( first_file )) || echo ","
        first_file=0
        printf '  "%s": [' "$(printf '%s' "$file" | json_escape)"
        local first_url=1
        for url in ${frameworkFiles[$file]}; do
            (( first_url )) || echo ","
            first_url=0
            printf '"%s"' "$(printf '%s' "$url" | json_escape)"
        done
        echo -n "]"
    done
    echo
    echo "}"
}

declare -A FRAMEWORK_DOCS=(
    [react]="https://react.dev/learn"
    [vue]="https://vuejs.org/guide/"
    [angular]="https://angular.io/docs"
    [svelte]="https://svelte.dev/docs"
    [django]="https://docs.djangoproject.com/en/stable/"
    [flask]="https://flask.palletsprojects.com/"
    [rails]="https://guides.rubyonrails.org/"
    [laravel]="https://laravel.com/docs"
    [spring]="https://spring.io/projects/spring-framework"
    [express]="https://expressjs.com/en/4x/api.html"
    [nextjs]="https://nextjs.org/docs"
    [nuxt]="https://nuxt.com/docs/getting-started/introduction"
    [gatsby]="https://www.gatsbyjs.com/docs/"
    [tailwind]="https://tailwindcss.com/docs"
    [bootstrap]="https://getbootstrap.com/docs/5.0/getting-started/introduction/"
    [jquery]="https://api.jquery.com/"
    [tensorflow]="https://www.tensorflow.org/learn"
    [pytorch]="https://pytorch.org/docs/stable/index.html"
    [docker]="https://docs.docker.com/"
    [kubernetes]="https://kubernetes.io/docs/home/"
    [ansible]="https://docs.ansible.com/"
    [terraform]="https://www.terraform.io/docs/index.html"
    [aws]="https://docs.aws.amazon.com/"
    [azure]="https://learn.microsoft.com/en-us/azure/"
    [gcp]="https://cloud.google.com/docs"
    [node]="https://nodejs.org/en/docs/"
    [npm]="https://docs.npmjs.com/"
    [yarn]="https://classic.yarnpkg.com/en/docs/"
    [pip]="https://pip.pypa.io/en/stable/"
    [poetry]="https://python-poetry.org/docs/"
    [maven]="https://maven.apache.org/guides/index.html"
    [gradle]="https://docs.gradle.org/current/userguide/userguide.html"
    [cargo]="https://doc.rust-lang.org/cargo/"
    [go_modules]="https://blog.golang.org/using-go-modules"
    [composer]="https://getcomposer.org/doc/"
    [bundler]="https://bundler.io/docs.html"
    [flutter]="https://flutter.dev/docs"
    [react_native]="https://reactnative.dev/docs/getting-started"
    [ionic]="https://ionicframework.com/docs"
    [cordova]="https://cordova.apache.org/docs/en/latest/"
    [electron]="https://www.electronjs.org/docs/latest"
    [unity]="https://docs.unity3d.com/Manual/index.html"
    [unreal]="https://docs.unrealengine.com/en-US/index.html"
    [godot]="https://docs.godotengine.org/en/stable/"
    [wordpress]="https://developer.wordpress.org/"
    [drupal]="https://www.drupal.org/docs"
    [joomla]="https://docs.joomla.org/"
    [shopify]="https://shopify.dev/docs"
    [magento]="https://developer.adobe.com/commerce/docs/"
    [salesforce]="https://developer.salesforce.com/docs"
    [sap]="https://help.sap.com/viewer/index"
    [oracle]="https://docs.oracle.com/en/"
    [mysql]="https://dev.mysql.com/doc/"
    [postgresql]="https://www.postgresql.org/docs/"
    [mongodb]="https://docs.mongodb.com/"
    [redis]="https://redis.io/documentation"
    [elasticsearch]="https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html"
    [rabbitmq]="https://www.rabbitmq.com/documentation.html"
    [kafka]="https://kafka.apache.org/documentation/"
    [prometheus]="https://prometheus.io/docs/introduction/overview/"
    [grafana]="https://grafana.com/docs/grafana/latest/"
    [jenkins]="https://www.jenkins.io/doc/"
    [circleci]="https://circleci.com/docs/"
    [travisci]="https://docs.travis-ci.com/"
    [github_actions]="https://docs.github.com/en/actions"
    [gitlab_ci]="https://docs.gitlab.com/ee/ci/"
    [bitbucket_pipelines]="https://support.atlassian.com/bitbucket-cloud/docs/get-started-with-bitbucket-pipelines/"
    [selenium]="https://www.selenium.dev/documentation/en/"
    [cypress]="https://docs.cypress.io/guides/overview/why-cypress"
    [jest]="https://jestjs.io/docs/getting-started"
    [mocha]="https://mochajs.org/#getting-started"
    [jasmine]="https://jasmine.github.io/pages/getting_started.html"
    [pytest]="https://docs.pytest.org/en/stable/"
    [unittest]="https://docs.python.org/3/library/unittest.html"
    [rspec]="https://rspec.info/documentation/"
    [capybara]="https://teamcapybara.github.io/capybara/"
    [selenium]="https://www.selenium.dev/documentation/en/"
    [cucumber]="https://cucumber.io/docs/guides/10-minute-tutorial/"
    [robot_framework]="https://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html"
)

print_entry() {
    local label="$1" file="$2" url="$3"
    if [[ -n "$url" ]]; then
        echo -e "  ${CYAN}${label}:${RESET} ${BOLD}$file${RESET}"
        echo -e "    ${GREEN}Docs:${RESET} $url"
    else
        warn "No known documentation for $file"
    fi
}

get_scrolls() {
    local TARGET_DIR="${1:-.}"
    local REQUESTED_ARRAY="${2:-}"

    REQUESTED_ARRAY="$(normalize "$REQUESTED_ARRAY")"

    dotFiles=()
    configFiles=()
    projectLangFiles=()
    frameworkFiles=()

    local -a project_dotfiles project_configfiles project_langfiles

    section "Scanning directory: $TARGET_DIR"

    mapfile -t project_dotfiles < <(
        find "$TARGET_DIR" -mindepth 1 -maxdepth 2 -type f -name ".*" ! -name "." ! -name ".."
    )

    mapfile -t project_configfiles < <(
        find "$TARGET_DIR" -mindepth 1 -maxdepth 2 -type f -iname "*config*"
    )

    mapfile -t project_langfiles < <(
        find "$TARGET_DIR" -mindepth 1 -maxdepth 2 -type f \( \
            -iname "*.py" -o -iname "*.js" -o -iname "*.sh" -o -iname "*.bash" \
            -o -iname "*.yaml" -o -iname "*.yml" -o -iname "*.ts" -o -iname "*.tsx" \
            -o -iname "*.jsx" -o -iname "*.go" -o -iname "*.rs" -o -iname "*.java" \
            -o -iname "*.cpp" -o -iname "*.c" -o -iname "*.css" -o -iname "*.html" \
            -o -iname "*.php" -o -iname "*.lua" -o -iname "*.rb" -o -iname "*.md" \
            -o -iname "*.json" -o -iname "*.xml" -o -iname "*.perl" -o -iname "*.pl" \
            -o -iname "*.swift" -o -iname "*.kt" -o -iname "*.scala" -o -iname "*.hs" \
            -o -iname "*.r" -o -iname "*.dart" -o -iname "*.elm" -o -iname "*.clj" \
            -o -iname "*.groovy" -o -iname "*.coffee" -o -iname "*.vb" -o -iname "*.fs" \
            -o -iname "*.scm" -o -iname "*.liquid" \
        \)
    )

    success "Dotfiles found: ${#project_dotfiles[@]}"
    success "Config files found: ${#project_configfiles[@]}"
    success "Language files found: ${#project_langfiles[@]}"

    section "Dotfiles"

    for path in "${project_dotfiles[@]}"; do
        file="$(basename "$path")"
        normalized_file="$(normalize "$file")"

        case "$normalized_file" in
            .gitignore)  dotFiles["$file"]="https://git-scm.com/docs/gitignore" ;;
            .env)        dotFiles["$file"]="https://12factor.net/config" ;;
            .bashrc)     dotFiles["$file"]="https://www.gnu.org/software/bash/manual/bash.html#Bash-Startup-Files" ;;
            .zshrc)      dotFiles["$file"]="https://zsh.sourceforge.io/Doc/Release/Files.html" ;;
            .vimrc)      dotFiles["$file"]="https://vimhelp.org/options.txt.html" ;;
            .tmux.conf)  dotFiles["$file"]="https://github.com/tmux/tmux/wiki" ;;
            .aliases)    dotFiles["$file"]="https://www.gnu.org/software/bash/manual/bash.html#Aliases" ;;
            *)           dotFiles["$file"]="https://www.google.com/search?q=${file}_documentation" ;;
        esac

        print_entry "Dotfile" "$file" "${dotFiles[$file]}"
    done

    section "Config Files & Frameworks"

    for path in "${project_configfiles[@]}"; do
        file="$(basename "$path")"
        normalized_file="$(normalize "$file")"

        case "$normalized_file" in
            package.json)      configFiles["$file"]="https://docs.npmjs.com/cli/v9/configuring-npm/package-json" ;;
            tsconfig.json)     configFiles["$file"]="https://www.typescriptlang.org/tsconfig" ;;
            webpack.config.js) configFiles["$file"]="https://webpack.js.org/concepts/configuration/" ;;
            .eslintrc*)        configFiles["$file"]="https://eslint.org/docs/latest/use/configure/" ;;
            .babelrc*)         configFiles["$file"]="https://babeljs.io/docs/en/configuration" ;;
            settings.y*ml)     configFiles["$file"]="https://yaml.org/spec/1.2/spec.html" ;;
            *)                 configFiles["$file"]="https://www.google.com/search?q=${file}_documentation" ;;
        esac

        IFS=' ._-' read -r -a parts <<< "$normalized_file"

        for part in "${parts[@]}"; do
            [[ -z "$part" ]] && continue
            if [[ -v "FRAMEWORK_DOCS[$part]" ]]; then
                frameworkFiles["$file"]+="${FRAMEWORK_DOCS[$part]} "
            fi
        done

        print_entry "Config" "$file" "${configFiles[$file]}"

        if [[ -n "${frameworkFiles[$file]:-}" ]]; then
            echo -e "  ${MAGENTA}Frameworks:${RESET}"
            printf "    %s\n" ${frameworkFiles[$file]}
        fi
    done

    section "Language Files"

    for path in "${project_langfiles[@]}"; do
        file="$(basename "$path")"
        normalized_file="$(normalize "$file")"
        ext="${normalized_file##*.}"

        case "$ext" in
            py)  projectLangFiles["$file"]="https://docs.python.org/3/" ;;
            js)  projectLangFiles["$file"]="https://developer.mozilla.org/docs/Web/JavaScript" ;;
            sh|bash) projectLangFiles["$file"]="https://www.gnu.org/software/bash/manual/bash.html" ;;
            yml|yaml) projectLangFiles["$file"]="https://yaml.org/spec/" ;;
            ts|tsx) projectLangFiles["$file"]="https://www.typescriptlang.org/docs/" ;;
            jsx) projectLangFiles["$file"]="https://react.dev/learn" ;;
            go)  projectLangFiles["$file"]="https://go.dev/doc/" ;;
            rs)  projectLangFiles["$file"]="https://doc.rust-lang.org/book/" ;;
            java) projectLangFiles["$file"]="https://docs.oracle.com/en/java/" ;;
            c|cpp) projectLangFiles["$file"]="https://en.cppreference.com/w/" ;;
            css) projectLangFiles["$file"]="https://developer.mozilla.org/docs/Web/CSS" ;;
            html) projectLangFiles["$file"]="https://developer.mozilla.org/docs/Web/HTML" ;;
            php) projectLangFiles["$file"]="https://www.php.net/docs.php" ;;
            lua) projectLangFiles["$file"]="https://www.lua.org/docs.html" ;;
            rb)  projectLangFiles["$file"]="https://www.ruby-lang.org/en/documentation/" ;;
            md)  projectLangFiles["$file"]="https://www.markdownguide.org/basic-syntax/" ;;
            liquid) projectLangFiles["$file"]="https://shopify.github.io/liquid/" ;;
            json) projectLangFiles["$file"]="https://www.json.org/json-en.html" ;;
            xml) projectLangFiles["$file"]="https://www.w3.org/XML/" ;;
            pl|perl) projectLangFiles["$file"]="https://perldoc.perl.org/" ;;
            swift) projectLangFiles["$file"]="https://swift.org/documentation/" ;;
            kt)   projectLangFiles["$file"]="https://kotlinlang.org/docs/home.html" ;;
            scala) projectLangFiles["$file"]="https://docs.scala-lang.org/" ;;
            hs)   projectLangFiles["$file"]="https://www.haskell.org/documentation/" ;;
            r)    projectLangFiles["$file"]="https://cran.r-project.org/manuals.html" ;;
            dart) projectLangFiles["$file"]="https://dart.dev/guides" ;;
            elm)  projectLangFiles["$file"]="https://guide.elm-lang.org/" ;;
            clj)  projectLangFiles["$file"]="https://clojure.org/reference/documentation" ;;
            groovy) projectLangFiles["$file"]="https://groovy-lang.org/documentation.html" ;;
            coffee) projectLangFiles["$file"]="https://coffeescript.org/#documentation" ;;
            vb)   projectLangFiles["$file"]="https://docs.microsoft.com/en-us/dotnet/visual-basic/" ;;
            fs)   projectLangFiles["$file"]="https://docs.microsoft.com/en-us/dotnet/fsharp/" ;;
            scm)  projectLangFiles["$file"]="https://mitpress.mit.edu/books/introduction-scheme" ;;
            *)   projectLangFiles["$file"]="https://www.google.com/search?q=${file}_documentation" ;;
        esac

        print_entry "Language" "$file" "${projectLangFiles[$file]}"
    done

    if [[ -n "$REQUESTED_ARRAY" ]]; then
        section "Requested keys: $REQUESTED_ARRAY"
        case "$REQUESTED_ARRAY" in
            dotfiles)         printf "%s\n" "${!dotFiles[@]}" ;;
            configfiles)      printf "%s\n" "${!configFiles[@]}" ;;
            projectlangfiles) printf "%s\n" "${!projectLangFiles[@]}" ;;
            frameworkfiles)   printf "%s\n" "${!frameworkFiles[@]}" ;;
            *) warn "Unknown array requested" ;;
        esac
    fi

    if [[ -n "${SAVE_SCROLLS:-}" ]]; then
        {
            echo "{"
            printf '  "directory": "%s",\n' "$(printf '%s' "$TARGET_DIR" | json_escape)"
            echo '  "dotfiles":'
            json_from_assoc dotFiles | sed 's/^/  /'
            echo ","
            echo '  "config_files":'
            json_from_assoc configFiles | sed 's/^/  /'
            echo ","
            echo '  "language_files":'
            json_from_assoc projectLangFiles | sed 's/^/  /'
            echo ","
            echo '  "frameworks":'
            json_from_frameworks | sed 's/^/  /'
            echo "}"
        } > "$SAVE_SCROLLS"
        success "Scrolls saved to $SAVE_SCROLLS"
    fi
}

COMMAND=""
ARRAY_REQUEST=""
SAVE_SCROLLS=""
TARGET_DIRS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -get_scrolls)
            COMMAND="get_scrolls"
            shift
            while [[ $# -gt 0 && "$1" != -* ]]; do
                TARGET_DIRS+=("$1")
                shift
            done
            ;;
        --save_scrolls)
            SAVE_SCROLLS="$2"
            shift 2
            ;;
        --l|--list)
            ARRAY_REQUEST="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./hermes -get_scrolls DIR [DIR ...] [--save_scrolls FILE] [--l ARRAY]"
            exit 0
            ;;
        *)
            error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

case "$COMMAND" in
    get_scrolls)
        [[ ${#TARGET_DIRS[@]} -eq 0 ]] && TARGET_DIRS=(.)
        for dir in "${TARGET_DIRS[@]}"; do
            get_scrolls "$dir" "$ARRAY_REQUEST"
        done
        ;;
    save_scrolls)
        error "--save_scrolls must be used with -get_scrolls"
        exit 1
        ;;
    list)
        error "--l|--list must be used with -get_scrolls"
        exit 1
        ;;
    *)
        error "No command specified"
        exit 1
        ;;
esac
