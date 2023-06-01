## Contributing

If you have any ideas, suggestions, or bugs to report, please open an issue or submit a pull request from your fork. Contributions are always welcome!

Notes on the file structure:

- `Sources/SimilaritySearchKit/Core` contains the main similarity search logic and helper methods that run 100% natively (i.e. *no dependencies*).
- `Sources/SimilaritySearchKit/AddOns` contains optional embedding models, and any other logic that *require external dependencies* and should be added as separate targets and imports. This is intended to reduce the size of the binary for users who don't need them.
