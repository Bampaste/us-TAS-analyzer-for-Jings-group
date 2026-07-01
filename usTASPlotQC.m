function usTASPlotQC(correction, outputFile)
%USTASPLOTQC Save raw A/B and corrected trace QC figure.

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1100, 720]);
tMicro = correction.time .* 1e6;

subplot(2, 1, 1);
plot(tMicro, correction.a, 'Color', [0.1 0.35 0.75], 'DisplayName', 'A track');
hold on;
plot(tMicro, correction.b, 'Color', [0.75 0.25 0.1], 'DisplayName', 'B track');
grid on;
xlabel('Time (\mus)');
ylabel('Signal (V)');
title(sprintf('Raw traces at %.0f nm', correction.wavelengthNm));
legend('Location', 'best');

subplot(2, 1, 2);
plot(tMicro, correction.corrected, 'k', 'DisplayName', 'Corrected A-B');
grid on;
xlabel('Time (\mus)');
ylabel('Corrected signal (V)');
title(correction.message, 'Interpreter', 'none');

exportgraphics(fig, outputFile, 'Resolution', 160);
close(fig);
end
