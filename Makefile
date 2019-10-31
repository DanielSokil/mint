development:
	crystal build src/mint.cr -o mint-dev -p --error-trace && \
	mv mint-dev ~/.bin/mint-dev && mint-dev

build:
	crystal build src/mint.cr -o mint -p --error-trace && mv mint ~/.bin/mint && mint

test:
	crystal spec -p --error-trace && bin/ameba

test-core:
	crystal build src/mint.cr -o mint -p --error-trace && cd core && ../mint test -b firefox && cd .. && rm mint

documentation:
	rm -rf docs && crystal docs

ls:
	crystal build src/lsp.cr -o mint-ls -p && mv mint-ls ~/.bin/mint-ls
