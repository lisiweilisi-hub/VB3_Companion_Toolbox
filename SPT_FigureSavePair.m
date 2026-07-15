function out = SPT_FigureSavePair(fig, basePath, F)
% SPT_FigureSavePair
% Save PNG/PDF pair for Figure Framework v2.
% MATLAB R2016b compatible.

out = struct('PNGFile', '', 'PDFFile', '');

if nargin < 1 || isempty(fig) || ~ishandle(fig)
    return;
end

if nargin < 3 || isempty(F) || ~isstruct(F)
    F = struct();
end

if ~isfield(F, 'SavePNG') || isempty(F.SavePNG)
    F.SavePNG = true;
end
if ~isfield(F, 'SavePDF') || isempty(F.SavePDF)
    F.SavePDF = false;
end
if ~isfield(F, 'DPI') || isempty(F.DPI)
    F.DPI = 300;
end

folderPath = fileparts(basePath);
if ~isempty(folderPath) && exist(folderPath, 'dir') ~= 7
    mkdir(folderPath);
end

set(fig, 'PaperPositionMode', 'auto');

if F.SavePNG
    out.PNGFile = [basePath '.png'];
    print(fig, out.PNGFile, '-dpng', ['-r' num2str(F.DPI)]);
end

if F.SavePDF
    out.PDFFile = [basePath '.pdf'];
    try
        print(fig, out.PDFFile, '-dpdf', '-painters');
    catch ME
        warning('PDF export failed for %s: %s', basePath, ME.message);
        out.PDFFile = '';
    end
end

end