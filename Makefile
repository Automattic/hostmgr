
lint:
	docker run -it -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.47.1

autocorrect:
	docker run -it -v `pwd`:`pwd` -w `pwd` ghcr.io/realm/swiftlint:0.47.1 swiftlint --autocorrect
