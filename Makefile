.PHONY: build clean test clean eio eio-shell

build:
	dune build

test:
	dune runtest

js-test:
	dune build @runjstest

clean:
	dune clean

.PHONY: nix/opam-selection.nix
nix/opam-selection.nix:
	nix-shell -A resolve default.nix

eio: #build eio
	dune build cohttp-eio

eio-shell: # nix-shell for eio dev
	nix-shell -p gmp libev nmap 
