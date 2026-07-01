function wavelengthNm = usTASParseWavelength(textValue)
%USTASPARSEWAVELENGTH Extract wavelength in nm from a path, filename, or label.

textValue = char(textValue);
tokens = regexp(textValue, '(\d+(?:\.\d+)?)\s*nm', 'tokens', 'once', 'ignorecase');
if isempty(tokens)
    tokens = regexp(textValue, '(^|[^\d])(\d{3,4})(?=[^\d]|$)', 'tokens', 'once');
    if isempty(tokens)
        wavelengthNm = NaN;
    else
        wavelengthNm = str2double(tokens{2});
    end
else
    wavelengthNm = str2double(tokens{1});
end
end
