classdef DrishtiSetuApp < handle
%DRISHTISETUAPP Professional Offline Clinical Screening Interface for DrishtiSetu.
%   app = DrishtiSetuApp() launches the offline-first screening application
%   for Primary Healthcare Centres (PHCs).
%
%   Includes 9 integrated clinical modules:
%       1. Dashboard
%       2. New Screening
%       3. Image Preview
%       4. Quality Assessment
%       5. AI Result (5-Level Grading & Referable Risk)
%       6. Explainability (Grad-CAM, Lesion Map, Vessel Tree)
%       7. Human-in-the-Loop Review (Accept, Modify, Reject)
%       8. Clinical Screening Report (PDF/PNG export)
%       9. History and Tamper-Evident Audit Log

    properties (Access = public)
        UIFigure
        TabGroup
        
        % Primary Screening Tab Controls
        ScreeningTab
        SelectImageBtn
        ImagePathLabel
        PatientIDField
        EyeDropDown
        RunScreeningBtn
        ExportReportBtn
        
        % Visual Axes
        OriginalAxes
        ProcessedAxes
        GradCAMAxes
        EvidenceAxes
        
        % Summary Badges & Cards
        QualityBadge
        QualityScoreLabel
        RecaptureAdviceLabel
        GradeBadge
        RiskLabel
        ConfidenceLabel
        UncertaintyLabel
        SafetyBadge
        DecisionReasonLabel
        ExplanationTextArea
        
        % Review Tab Controls
        ReviewTab
        ReviewCaseIDLabel
        ReviewGradeDropDown
        ReviewerNameField
        ReviewNotesField
        AcceptBtn
        ModifyBtn
        RejectBtn
        ReviewStatusLabel
        
        % Report Tab Controls
        ReportTab
        ReportSummaryArea
        ViewPDFBtn
        ViewPNGBtn
        
        % Estimated 3D Retina Tab Controls (M13)
        ThreeDTab
        ThreeDAxes
        BScanAxes
        ThreeDStatusBadge
        ThreeDModeLabel
        ElevationSpanLabel
        ThreeDDetailArea
        ViewIsoBtn
        ViewTopBtn
        ViewSideBtn
        
        % History / Audit Tab Controls
        HistoryTab
        HistoryTable
        RefreshHistoryBtn
        AuditTextArea
    end

    properties (Access = private)
        ProjectRoot
        CurrentResult
        Theme
        SelectedImagePath
        SelectedImage
    end

    methods
        function app = DrishtiSetuApp(varargin)
            % Initialize project path
            thisFile = mfilename('fullpath');
            app.ProjectRoot = fileparts(fileparts(thisFile));
            addpath(genpath(app.ProjectRoot));
            
            % Palette
            app.Theme = struct( ...
                'bg', [0.06, 0.08, 0.10], ...
                'surface', [0.10, 0.13, 0.17], ...
                'raised', [0.14, 0.18, 0.23], ...
                'field', [0.18, 0.22, 0.28], ...
                'text', [0.92, 0.94, 0.96], ...
                'muted', [0.58, 0.64, 0.70], ...
                'accent', [0.18, 0.65, 0.95], ...
                'green', [0.15, 0.80, 0.50], ...
                'amber', [0.95, 0.65, 0.15], ...
                'red', [0.95, 0.30, 0.30]);
            
            % Build UI Components
            app.createComponents();
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function initSampleList(app)
            sampleDir = fullfile(app.ProjectRoot, 'demo', 'sample_images');
            if ~isfolder(sampleDir)
                populateDemoDataset();
            end
            app.SampleCases = { ...
                'Normal Fundus (Level 0)', fullfile(sampleDir, 'sample_normal_01.png'); ...
                'Mild NPDR - Early MAs (Level 1)', fullfile(sampleDir, 'sample_mild_01.png'); ...
                'Moderate NPDR - Referable (Level 2)', fullfile(sampleDir, 'sample_moderate_01.png'); ...
                'Severe NPDR - High Risk (Level 3)', fullfile(sampleDir, 'sample_severe_01.png'); ...
                'Borderline Quality (Auto-Enhanced)', fullfile(sampleDir, 'sample_borderline_01.png'); ...
                'Ungradable Capture (Recapture Advice)', fullfile(sampleDir, 'sample_ungradable_01.png') ...
            };
        end

        function createComponents(app)
            t = app.Theme;
            
            app.UIFigure = uifigure('Name', 'DrishtiSetu  |  Explainable AI for Diabetic Retinopathy Screening', ...
                'Position', [50, 40, 1500, 920], 'Color', t.bg);

            mainLayout = uigridlayout(app.UIFigure, [2, 1]);
            mainLayout.RowHeight = {65, '1x'};
            mainLayout.Padding = [15, 10, 15, 10];
            mainLayout.RowSpacing = 8;
            mainLayout.BackgroundColor = t.bg;

            % --- TOP HEADER BAR ---
            headerPanel = uipanel(mainLayout, 'BackgroundColor', t.surface, 'BorderType', 'none');
            headerLayout = uigridlayout(headerPanel, [1, 3]);
            headerLayout.ColumnWidth = {'1.5x', '1x', '1.2x'};
            headerLayout.Padding = [15, 5, 15, 5];

            titleLabel = uilabel(headerLayout, 'Text', 'DRISHTISETU', ...
                'FontSize', 22, 'FontWeight', 'bold', 'FontColor', t.accent);
            subLabel = uilabel(headerLayout, 'Text', 'Offline Explainable AI for Rural Retinal Triage', ...
                'FontSize', 12, 'FontColor', t.muted, 'HorizontalAlignment', 'center');
            statusLabel = uilabel(headerLayout, 'Text', 'Offline-First Engine  |  Operating Point Frozen', ...
                'FontSize', 11, 'FontColor', t.green, 'HorizontalAlignment', 'right');

            % --- MAIN TAB GROUP ---
            app.TabGroup = uitabgroup(mainLayout);

            % 1. Screening Tab
            app.ScreeningTab = uitab(app.TabGroup, 'Title', '1. Clinical Screening');
            app.createScreeningTab();

            % 2. Estimated 3D Retina Tab (Module M13)
            app.ThreeDTab = uitab(app.TabGroup, 'Title', '2. Estimated 3D Retina');
            app.createThreeDTab();

            % 3. Review Tab
            app.ReviewTab = uitab(app.TabGroup, 'Title', '3. Human Review');
            app.createReviewTab();

            % 4. Report Tab
            app.ReportTab = uitab(app.TabGroup, 'Title', '4. Clinical Report');
            app.createReportTab();

            % 5. History Tab
            app.HistoryTab = uitab(app.TabGroup, 'Title', '5. Case History & Audit');
            app.createHistoryTab();
        end

        function createScreeningTab(app)
            t = app.Theme;
            grid = uigridlayout(app.ScreeningTab, [1, 2]);
            grid.ColumnWidth = {340, '1x'};
            grid.BackgroundColor = t.bg;
            grid.Padding = [10, 10, 10, 10];

            % --- LEFT CONTROL & RESULT PANEL ---
            leftPanel = uipanel(grid, 'BackgroundColor', t.surface, 'BorderType', 'none');
            leftLayout = uigridlayout(leftPanel, [13, 1]);
            leftLayout.RowHeight = {28, 36, 22, 32, 42, 24, 40, 40, 40, 35, 35, '1x', 40};
            leftLayout.Padding = [12, 10, 12, 10];
            leftLayout.RowSpacing = 6;

            uilabel(leftLayout, 'Text', 'LIVE FUNDUS ACQUISITION', 'FontWeight', 'bold', 'FontColor', t.muted);

            % Open Real Fundus Image Button
            app.SelectImageBtn = uibutton(leftLayout, 'Text', 'Open Fundus Image...', ...
                'FontWeight', 'bold', 'FontSize', 13, ...
                'BackgroundColor', t.accent, 'FontColor', [1, 1, 1], ...
                'ButtonPushedFcn', @(s, e) app.onSelectImage());

            % Image Status / Filename Label
            app.ImagePathLabel = uilabel(leftLayout, 'Text', 'No image selected (Click above to load)', ...
                'FontSize', 10, 'FontColor', t.muted, 'HorizontalAlignment', 'center');

            % Patient Pseudo-ID & Eye
            patGrid = uigridlayout(leftLayout, [1, 2]);
            patGrid.ColumnWidth = {'1x', 80};
            patGrid.Padding = [0, 0, 0, 0];
            patGrid.BackgroundColor = t.surface;
            app.PatientIDField = uieditfield(patGrid, 'text', 'Value', 'P-RURAL-042', ...
                'BackgroundColor', t.field, 'FontColor', t.text);
            app.EyeDropDown = uidropdown(patGrid, 'Items', {'OD (Right)', 'OS (Left)'}, ...
                'BackgroundColor', t.field, 'FontColor', t.text);

            % Action Button
            app.RunScreeningBtn = uibutton(leftLayout, 'Text', 'Run DrishtiSetu Screening', ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'BackgroundColor', t.green, 'FontColor', [1, 1, 1], ...
                'ButtonPushedFcn', @(s, e) app.onRunScreening());

            uilabel(leftLayout, 'Text', 'CLINICAL TRIAGE STATUS', 'FontWeight', 'bold', 'FontColor', t.muted);

            % Quality Result Card
            app.QualityBadge = uilabel(leftLayout, 'Text', 'Quality: Ready to Assess', ...
                'FontWeight', 'bold', 'FontSize', 13, 'FontColor', t.muted, ...
                'BackgroundColor', t.raised, 'HorizontalAlignment', 'center');

            % AI DR Grade Card
            app.GradeBadge = uilabel(leftLayout, 'Text', 'AI Severity: Ready to Analyze', ...
                'FontWeight', 'bold', 'FontSize', 13, 'FontColor', t.accent, ...
                'BackgroundColor', t.raised, 'HorizontalAlignment', 'center');

            % Calibrated Risk & Confidence
            metricGrid = uigridlayout(leftLayout, [1, 2]);
            metricGrid.Padding = [0, 0, 0, 0];
            metricGrid.BackgroundColor = t.surface;
            app.RiskLabel = uilabel(metricGrid, 'Text', 'Risk: --', 'FontColor', t.text, 'FontSize', 11);
            app.ConfidenceLabel = uilabel(metricGrid, 'Text', 'Conf: --', 'FontColor', t.text, 'FontSize', 11);

            % Safety Status Badge
            app.SafetyBadge = uilabel(leftLayout, 'Text', 'Safety Gate: READY', ...
                'FontWeight', 'bold', 'FontColor', t.muted, 'BackgroundColor', t.raised, ...
                'HorizontalAlignment', 'center');

            app.DecisionReasonLabel = uilabel(leftLayout, 'Text', 'Ready for clinical intake.', ...
                'FontSize', 10, 'FontColor', t.muted);

            % Dynamic Clinical Explanation
            app.ExplanationTextArea = uitextarea(leftLayout, ...
                'Value', {'Select a live fundus photo and click "Run DrishtiSetu Screening" to begin.'}, ...
                'BackgroundColor', t.field, 'FontColor', t.text, 'FontSize', 11, 'Editable', 'off');

            % Report Export Button
            app.ExportReportBtn = uibutton(leftLayout, 'Text', 'Export Clinical Report (PDF)', ...
                'BackgroundColor', t.raised, 'FontColor', t.text, ...
                'ButtonPushedFcn', @(s, e) app.onExportReport());

            % --- RIGHT 4-IMAGE WORKSPACE ---
            rightPanel = uipanel(grid, 'BackgroundColor', t.surface, 'BorderType', 'none');
            rightLayout = uigridlayout(rightPanel, [2, 2]);
            rightLayout.Padding = [8, 8, 8, 8];
            rightLayout.RowSpacing = 8;
            rightLayout.ColumnSpacing = 8;
            rightLayout.BackgroundColor = t.surface;

            app.OriginalAxes = uiaxes(rightLayout, 'Color', t.bg, 'XColor', 'none', 'YColor', 'none');
            title(app.OriginalAxes, '1. Original Fundus Capture (High Fidelity)', 'Color', t.text, 'FontSize', 11);

            app.ProcessedAxes = uiaxes(rightLayout, 'Color', t.bg, 'XColor', 'none', 'YColor', 'none');
            title(app.ProcessedAxes, '2. Native Retinal Field (High Fidelity)', 'Color', t.text, 'FontSize', 11);

            app.GradCAMAxes = uiaxes(rightLayout, 'Color', t.bg, 'XColor', 'none', 'YColor', 'none');
            title(app.GradCAMAxes, '3. AI Attention / Saliency Map', 'Color', t.text, 'FontSize', 11);

            app.EvidenceAxes = uiaxes(rightLayout, 'Color', t.bg, 'XColor', 'none', 'YColor', 'none');
            title(app.EvidenceAxes, '4. Biomarkers & Lesion Localisation', 'Color', t.text, 'FontSize', 11);
        end

        function createThreeDTab(app)
            t = app.Theme;
            grid3D = uigridlayout(app.ThreeDTab, [1, 2]);
            grid3D.ColumnWidth = {360, '1x'};
            grid3D.BackgroundColor = t.bg;
            grid3D.Padding = [12, 12, 12, 12];

            % Left Controls & Metrics Panel
            leftPnl = uipanel(grid3D, 'BackgroundColor', t.surface, 'BorderType', 'none');
            lLayout = uigridlayout(leftPnl, [8, 1]);
            lLayout.RowHeight = {28, 36, 40, 40, 36, '1x', 140, 24};
            lLayout.Padding = [12, 12, 12, 12];
            lLayout.RowSpacing = 8;

            uilabel(lLayout, 'Text', 'ADVANCED ESTIMATED 3D RETINA', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', t.accent);

            app.ThreeDStatusBadge = uilabel(lLayout, 'Text', 'Status: Ready for 3D Estimation', ...
                'FontWeight', 'bold', 'FontSize', 12, 'FontColor', t.muted, ...
                'BackgroundColor', t.raised, 'HorizontalAlignment', 'center');

            app.ThreeDModeLabel = uilabel(lLayout, 'Text', 'Mode: Fundus-Derived Relief', ...
                'FontColor', t.text, 'FontSize', 11);

            app.ElevationSpanLabel = uilabel(lLayout, 'Text', 'Elevation Span: -- um', ...
                'FontColor', t.green, 'FontSize', 12, 'FontWeight', 'bold');

            % View Presets
            presetGrid = uigridlayout(lLayout, [1, 3]);
            presetGrid.Padding = [0, 0, 0, 0];
            presetGrid.BackgroundColor = t.surface;

            app.ViewIsoBtn = uibutton(presetGrid, 'Text', 'Isometric', ...
                'BackgroundColor', t.raised, 'FontColor', t.text, 'FontSize', 10, ...
                'ButtonPushedFcn', @(s, e) app.set3DView([-35, 42]));
            app.ViewTopBtn = uibutton(presetGrid, 'Text', 'Top-Down', ...
                'BackgroundColor', t.raised, 'FontColor', t.text, 'FontSize', 10, ...
                'ButtonPushedFcn', @(s, e) app.set3DView([0, 90]));
            app.ViewSideBtn = uibutton(presetGrid, 'Text', 'Side Profile', ...
                'BackgroundColor', t.raised, 'FontColor', t.text, 'FontSize', 10, ...
                'ButtonPushedFcn', @(s, e) app.set3DView([-90, 0]));

            % Detailed 3D Metrics Area
            app.ThreeDDetailArea = uitextarea(lLayout, ...
                'Value', {'Run screening on a fundus image to generate 3D vascular topography and synthetic B-scan.'}, ...
                'BackgroundColor', t.field, 'FontColor', t.text, 'FontSize', 11, 'Editable', 'off');

            % Cross-Sectional B-Scan Axes
            app.BScanAxes = uiaxes(lLayout, 'Color', t.bg, 'XColor', t.muted, 'YColor', t.muted);
            title(app.BScanAxes, 'Synthetic B-Scan (Disc -> Fovea)', 'Color', t.text, 'FontSize', 10);

            uilabel(lLayout, 'Text', 'Decoupled: 3D visualization does not alter primary DR grade.', ...
                'FontSize', 9, 'FontColor', t.muted, 'HorizontalAlignment', 'center');

            % Right Large 3D Display Panel
            rightPnl = uipanel(grid3D, 'BackgroundColor', t.surface, 'BorderType', 'none');
            rLayout = uigridlayout(rightPnl, [1, 1]);
            rLayout.Padding = [8, 8, 8, 8];
            rLayout.BackgroundColor = t.surface;

            app.ThreeDAxes = uiaxes(rLayout, 'Color', t.bg, 'XColor', t.muted, 'YColor', t.muted, 'ZColor', t.muted);
            title(app.ThreeDAxes, 'Estimated 3D Retinal Surface & Vascular Caliber Elevation', ...
                'Color', t.text, 'FontSize', 12, 'FontWeight', 'bold');
            view(app.ThreeDAxes, [-35, 42]);
        end

        function set3DView(app, angles)
            if ~isempty(app.ThreeDAxes) && isvalid(app.ThreeDAxes)
                view(app.ThreeDAxes, angles);
            end
        end

        function createReviewTab(app)
            t = app.Theme;
            rGrid = uigridlayout(app.ReviewTab, [7, 1]);
            rGrid.RowHeight = {30, 40, 40, 40, '1x', 50, 40};
            rGrid.Padding = [30, 20, 30, 20];
            rGrid.BackgroundColor = t.bg;

            uilabel(rGrid, 'Text', 'HUMAN-IN-THE-LOOP OPHTHALMOLOGIST REVIEW', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', t.accent);

            app.ReviewCaseIDLabel = uilabel(rGrid, 'Text', 'Active Case: None Selected', ...
                'FontSize', 13, 'FontColor', t.text);

            % Reviewer Name & Override Grade
            formGrid = uigridlayout(rGrid, [1, 2]);
            formGrid.Padding = [0, 0, 0, 0];
            formGrid.BackgroundColor = t.bg;
            app.ReviewerNameField = uieditfield(formGrid, 'text', ...
                'Value', 'Dr. V. Raman, MS (Ophthalmology)', 'BackgroundColor', t.field, 'FontColor', t.text);
            app.ReviewGradeDropDown = uidropdown(formGrid, ...
                'Items', {'Grade 0: No DR', 'Grade 1: Mild NPDR', 'Grade 2: Moderate NPDR', ...
                          'Grade 3: Severe NPDR', 'Grade 4: Proliferative DR'}, ...
                'BackgroundColor', t.field, 'FontColor', t.text);

            uilabel(rGrid, 'Text', 'Clinical Sign-off Notes & Findings Rationale:', ...
                'FontColor', t.muted, 'FontSize', 12);

            app.ReviewNotesField = uitextarea(rGrid, ...
                'Value', {'Concordant with clinical findings. Dilated fundus examination recommended.'}, ...
                'BackgroundColor', t.field, 'FontColor', t.text, 'FontSize', 12);

            % Action Buttons
            btnGrid = uigridlayout(rGrid, [1, 3]);
            btnGrid.Padding = [0, 0, 0, 0];
            btnGrid.BackgroundColor = t.bg;

            app.AcceptBtn = uibutton(btnGrid, 'Text', 'ACCEPT AI Recommendation', ...
                'BackgroundColor', t.green, 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(s, e) app.onFinalizeReview('ACCEPT'));

            app.ModifyBtn = uibutton(btnGrid, 'Text', 'MODIFY Grade', ...
                'BackgroundColor', t.amber, 'FontColor', [0, 0, 0], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(s, e) app.onFinalizeReview('MODIFY'));

            app.RejectBtn = uibutton(btnGrid, 'Text', 'REJECT / Order Recapture', ...
                'BackgroundColor', t.red, 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(s, e) app.onFinalizeReview('REJECT'));

            app.ReviewStatusLabel = uilabel(rGrid, 'Text', 'Review Status: PENDING', ...
                'FontSize', 12, 'FontColor', t.muted, 'HorizontalAlignment', 'center');
        end

        function createReportTab(app)
            t = app.Theme;
            repGrid = uigridlayout(app.ReportTab, [3, 1]);
            repGrid.RowHeight = {35, '1x', 45};
            repGrid.Padding = [25, 20, 25, 20];
            repGrid.BackgroundColor = t.bg;

            uilabel(repGrid, 'Text', 'CLINICAL SCREENING REPORT SUMMARY', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', t.accent);

            app.ReportSummaryArea = uitextarea(repGrid, ...
                'Value', {'No report generated yet. Run a screening case to produce report.'}, ...
                'BackgroundColor', t.field, 'FontColor', t.text, 'FontSize', 12, 'Editable', 'off');

            btnRow = uigridlayout(repGrid, [1, 2]);
            btnRow.Padding = [0, 0, 0, 0];
            btnRow.BackgroundColor = t.bg;

            app.ViewPDFBtn = uibutton(btnRow, 'Text', 'Open PDF Screening Report', ...
                'BackgroundColor', t.accent, 'FontColor', [1, 1, 1], 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(s, e) app.openReportFile('pdf'));

            app.ViewPNGBtn = uibutton(btnRow, 'Text', 'Open PNG Screening Card', ...
                'BackgroundColor', t.raised, 'FontColor', t.text, ...
                'ButtonPushedFcn', @(s, e) app.openReportFile('png'));
        end

        function createHistoryTab(app)
            t = app.Theme;
            histGrid = uigridlayout(app.HistoryTab, [4, 1]);
            histGrid.RowHeight = {35, '1x', 35, 120};
            histGrid.Padding = [20, 15, 20, 15];
            histGrid.BackgroundColor = t.bg;

            topRow = uigridlayout(histGrid, [1, 2]);
            topRow.Padding = [0, 0, 0, 0];
            topRow.BackgroundColor = t.bg;
            uilabel(topRow, 'Text', 'LOCAL SCREENING REGISTRY & AUDIT TRAILS', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', t.accent);
            app.RefreshHistoryBtn = uibutton(topRow, 'Text', 'Refresh Database Index', ...
                'BackgroundColor', t.raised, 'FontColor', t.text, ...
                'ButtonPushedFcn', @(s, e) app.refreshHistory());

            app.HistoryTable = uitable(histGrid, 'BackgroundColor', [t.field; t.surface]);

            uilabel(histGrid, 'Text', 'Tamper-Evident Audit Trail Log:', ...
                'FontColor', t.muted, 'FontWeight', 'bold');

            app.AuditTextArea = uitextarea(histGrid, ...
                'BackgroundColor', t.field, 'FontColor', t.text, 'FontSize', 10, 'Editable', 'off');

            app.refreshHistory();
        end

        function onSelectImage(app)
            [fileName, folderPath] = uigetfile({ ...
                '*.png;*.jpg;*.jpeg;*.tif;*.tiff;*.dcm;*.bmp', 'Fundus Image Files (*.png, *.jpg, *.jpeg, *.tif, *.dcm, *.bmp)'; ...
                '*.png;*.jpg;*.jpeg', 'Standard Images (*.png, *.jpg, *.jpeg)'; ...
                '*.tif;*.tiff', 'TIFF Medical Images (*.tif, *.tiff)'; ...
                '*.dcm', 'DICOM Medical Images (*.dcm)'; ...
                '*.*', 'All Files (*.*)'}, ...
                'Select Live Retinal Fundus Photograph for DrishtiSetu Screening');
            
            if isequal(fileName, 0) || isequal(folderPath, 0)
                return;
            end
            
            filePath = fullfile(folderPath, fileName);
            app.loadUserImage(filePath);
        end

        function loadUserImage(app, filePath)
            t = app.Theme;
            try
                [img, ~, meta] = loadFundusImage(filePath);
                app.SelectedImagePath = filePath;
                app.SelectedImage = img;
                
                [h, w, ~] = size(img);
                [~, baseName, ext] = fileparts(filePath);
                app.ImagePathLabel.Text = sprintf('%s%s  (%d x %d px)', baseName, ext, w, h);
                app.ImagePathLabel.FontColor = t.green;
                
                % Preview original image immediately in native high fidelity
                imshow(img, 'Parent', app.OriginalAxes);
                title(app.OriginalAxes, '1. Original Fundus Capture (High Fidelity)', 'Color', t.text);
                
                % Reset downstream status ready for screening
                app.QualityBadge.Text = 'Quality: Ready to Assess';
                app.QualityBadge.FontColor = t.muted;
                app.GradeBadge.Text = 'AI Severity: Ready to Analyze';
                app.GradeBadge.FontColor = t.accent;
                app.SafetyBadge.Text = 'Safety Gate: READY';
                app.SafetyBadge.FontColor = t.muted;
                app.RiskLabel.Text = 'Risk: --';
                app.ConfidenceLabel.Text = 'Conf: --';
                app.DecisionReasonLabel.Text = 'Image loaded. Click "Run DrishtiSetu Screening" to begin.';
                app.ExplanationTextArea.Value = {'Ready for live screening. Press "Run DrishtiSetu Screening".'};
            catch ME
                uialert(app.UIFigure, sprintf('Failed to read fundus image: %s', ME.message), ...
                    'Image Load Error', 'Icon', 'error');
            end
        end

        function onRunScreening(app)
            if isempty(app.SelectedImagePath) || ~isfile(app.SelectedImagePath)
                app.onSelectImage();
                if isempty(app.SelectedImagePath) || ~isfile(app.SelectedImagePath)
                    return;
                end
            end

            pID = char(app.PatientIDField.Value);
            eye = char(app.EyeDropDown.Value);
            if contains(eye, 'OD'); eyeCode = 'OD'; else; eyeCode = 'OS'; end
            pInfo = struct('pseudoID', pID, 'age', 54, 'gender', 'M', 'diabetesYears', 7);

            % Show progress dialog
            prog = uiprogressdlg(app.UIFigure, 'Title', 'DrishtiSetu Clinical Engine', ...
                'Message', 'Processing live screening pipeline (Quality -> Anatomy -> Lesions -> Decision)...', ...
                'Indeterminate', 'on');
            cleanupProg = onCleanup(@() close(prog));

            % Run complete pipeline
            res = runScreeningCase(app.SelectedImagePath, pInfo, eyeCode);
            app.CurrentResult = res;

            % Update UI Views
            app.renderScreeningResult(res);
            app.refreshHistory();
        end

        function renderScreeningResult(app, res)
            t = app.Theme;

            % 1. Render Images
            if ~isempty(res.acquisition.originalImage)
                imshow(res.acquisition.originalImage, 'Parent', app.OriginalAxes);
                title(app.OriginalAxes, '1. Original Fundus Capture (High Fidelity)', 'Color', t.text);
            end
            if ~isempty(res.preprocessing.processedImage)
                imshow(res.preprocessing.processedImage, 'Parent', app.ProcessedAxes);
                title(app.ProcessedAxes, '2. Native Retinal Field (High Fidelity)', 'Color', t.text);
            end
            if ~isempty(res.explainability.gradCAMOverlay)
                imshow(res.explainability.gradCAMOverlay, 'Parent', app.GradCAMAxes);
                title(app.GradCAMAxes, '3. AI Attention / Saliency Map', 'Color', t.text);
            end
            if ~isempty(res.explainability.lesionOverlay)
                imshow(res.explainability.lesionOverlay, 'Parent', app.EvidenceAxes);
                title(app.EvidenceAxes, '4. Biomarkers & Lesion Localisation', 'Color', t.text);
            end

            % 2. Quality Card
            qClass = res.quality.qualityClass;
            qScore = res.quality.qualityScore;
            if strcmp(qClass, 'GOOD')
                app.QualityBadge.Text = sprintf('Quality: GOOD (%.0f%%)', qScore);
                app.QualityBadge.FontColor = t.green;
            elseif strcmp(qClass, 'BORDERLINE')
                app.QualityBadge.Text = sprintf('Quality: BORDERLINE (%.0f%%)', qScore);
                app.QualityBadge.FontColor = t.amber;
            else
                app.QualityBadge.Text = sprintf('Quality: BAD / UNGRADABLE (%.0f%%)', qScore);
                app.QualityBadge.FontColor = t.red;
            end

            % 3. AI DR Grade Card
            if isnan(res.dr.drGrade)
                app.GradeBadge.Text = 'AI Severity: Gated (Ungradable)';
                app.GradeBadge.FontColor = t.red;
            else
                refStr = 'Routine Screening';
                if res.dr.referable; refStr = 'REFERABLE DR'; end
                app.GradeBadge.Text = sprintf('%s  |  %s', res.dr.drLabel, refStr);
                if res.dr.referable
                    app.GradeBadge.FontColor = t.red;
                else
                    app.GradeBadge.FontColor = t.green;
                end
            end

            % 4. Risk & Confidence
            app.RiskLabel.Text = sprintf('Referable Risk: %.1f%%', res.dr.calibratedReferableProbability * 100);
            app.ConfidenceLabel.Text = sprintf('Confidence: %.1f%%', res.safety.confidenceScore * 100);

            % 5. Safety Badge
            sStat = res.safety.safetyStatus;
            app.SafetyBadge.Text = sprintf('Safety Gate: %s', sStat);
            if strcmp(sStat, 'SAFE_FOR_AI_ASSISTED_RESULT')
                app.SafetyBadge.FontColor = t.green;
            elseif strcmp(sStat, 'HUMAN_REVIEW_REQUIRED')
                app.SafetyBadge.FontColor = t.amber;
            else
                app.SafetyBadge.FontColor = t.red;
            end

            if isfield(res.safety, 'decisionReason')
                app.DecisionReasonLabel.Text = res.safety.decisionReason;
            end

            % 6. Explanation Text
            app.ExplanationTextArea.Value = splitlines(res.explainability.explanationNarrative);

            % 7. Review Tab update
            app.ReviewCaseIDLabel.Text = sprintf('Active Case: %s (Patient: %s, Eye: %s)', ...
                res.caseID, res.patient.pseudoID, res.eye);
            app.ReviewStatusLabel.Text = sprintf('Review Status: %s', res.review.status);

            % 8. Report Tab update
            if isfield(res.report, 'summaryText') && ~isempty(res.report.summaryText)
                app.ReportSummaryArea.Value = splitlines(res.report.summaryText);
            end

            % 9. Estimated 3D Retina Tab update (Module M13)
            if isfield(res, 'advanced3D') && isfield(res.advanced3D, 'status') && ...
               (strcmp(res.advanced3D.status, 'COMPLETED') || ~isempty(res.advanced3D.rendered3DImage))
                try
                    spanVal = 0;
                    if isfield(res.advanced3D, 'elevationSpan'); spanVal = res.advanced3D.elevationSpan; end
                    app.ThreeDStatusBadge.Text = sprintf('Status: 3D RECONSTRUCTED (Span: %.0f um)', spanVal);
                    app.ThreeDStatusBadge.FontColor = t.green;
                    app.ThreeDModeLabel.Text = sprintf('Mode: %s', res.advanced3D.mode);
                    app.ElevationSpanLabel.Text = sprintf('Elevation Span: %.1f um', spanVal);

                    if isfield(res.advanced3D, 'depthInfo') && isfield(res.advanced3D.depthInfo, 'zSurface')
                        visualizeRetina3D(res.advanced3D.depthInfo, 'TargetAxes', app.ThreeDAxes);
                        
                        dInfo = res.advanced3D.depthInfo;
                        if isfield(dInfo, 'bScanProfile') && ~isempty(dInfo.bScanProfile.depthCurve)
                            cla(app.BScanAxes);
                            hold(app.BScanAxes, 'on');
                            bArc = dInfo.bScanProfile.arcLength;
                            bCur = dInfo.bScanProfile.depthCurve;
                            plot(app.BScanAxes, bArc, bCur, 'Color', t.accent, 'LineWidth', 2);
                            plot(app.BScanAxes, bArc, bCur - 120, '--', 'Color', t.green, 'LineWidth', 1);
                            plot(app.BScanAxes, bArc, bCur - 250, 'Color', t.amber, 'LineWidth', 1.5);
                            grid(app.BScanAxes, 'on');
                            xlabel(app.BScanAxes, 'Distance (px)', 'Color', t.muted, 'FontSize', 8);
                            ylabel(app.BScanAxes, 'Elevation (um)', 'Color', t.muted, 'FontSize', 8);
                            title(app.BScanAxes, 'Synthetic B-Scan Profile (Optic Disc -> Fovea)', 'Color', t.text, 'FontSize', 10);
                            hold(app.BScanAxes, 'off');
                        end

                        lines3D = { ...
                            sprintf('Reconstruction: %s', res.advanced3D.status), ...
                            sprintf('Method: Anatomical Relief & Vascular Caliber Elevation'), ...
                            sprintf('Structural Prior: %s', res.advanced3D.mode), ...
                            sprintf('Elevation Span: %.1f um (Range: %.0f to %.0f um)', ...
                                spanVal, dInfo.minElevation, dInfo.maxElevation), ...
                            sprintf('Optic Cup Excavation: Enabled (~280 um depth)'), ...
                            sprintf('Foveal Pit Depression: Enabled (~135 um depth)'), ...
                            sprintf('Vessel Ridge Profiling: Continuous caliber elevation'), ...
                            '', ...
                            'CLINICAL ISOLATION GUARANTEE:', ...
                            'Advanced 3D visualization operates independently.', ...
                            'Primary DR diagnosis & referral decisions are unaffected.' ...
                        };
                        app.ThreeDDetailArea.Value = lines3D;
                    elseif ~isempty(res.advanced3D.rendered3DImage)
                        imshow(res.advanced3D.rendered3DImage, 'Parent', app.ThreeDAxes);
                        title(app.ThreeDAxes, 'Estimated 3D Retinal Surface (M13)', 'Color', t.text);
                    end
                catch ME
                    app.ThreeDStatusBadge.Text = 'Status: 3D Visualization Fallback';
                    app.ThreeDStatusBadge.FontColor = t.amber;
                end
            end
        end

        function onFinalizeReview(app, decision)
            if isempty(app.CurrentResult)
                uialert(app.UIFigure, 'Please run a screening case before reviewing.', 'No Active Case');
                return;
            end

            reviewerID = char(app.ReviewerNameField.Value);
            notes = char(app.ReviewNotesField.Value);
            valStr = char(app.ReviewGradeDropDown.Value);
            modifiedGrade = str2double(valStr(7)); % 'Grade X: ...'

            updated = finalizeReview(app.CurrentResult, decision, reviewerID, notes, modifiedGrade);
            app.CurrentResult = updated;

            app.ReviewStatusLabel.Text = sprintf('Review Status: %s by %s', decision, reviewerID);
            app.renderScreeningResult(updated);
            app.refreshHistory();
            uialert(app.UIFigure, sprintf('Review determination "%s" recorded successfully.', decision), ...
                'Review Confirmed');
        end

        function onExportReport(app)
            if isempty(app.CurrentResult)
                uialert(app.UIFigure, 'Please run a screening case before exporting.', 'No Case Available');
                return;
            end
            repOut = generateReport(app.CurrentResult);
            app.openReportFile('pdf');
        end

        function openReportFile(app, ext)
            if isempty(app.CurrentResult) || ~isfield(app.CurrentResult.report, 'reportPDFPath')
                uialert(app.UIFigure, 'No report file available.', 'File Missing');
                return;
            end
            if strcmp(ext, 'pdf')
                fPath = app.CurrentResult.report.reportPDFPath;
            else
                fPath = app.CurrentResult.report.reportPNGPath;
            end
            if isfile(fPath)
                open(fPath);
            else
                uialert(app.UIFigure, sprintf('File not found: %s', fPath), 'File Error');
            end
        end

        function refreshHistory(app)
            dbPath = fullfile(app.ProjectRoot, 'data', 'drishtisetu_db.mat');
            if isfile(dbPath)
                loaded = load(dbPath);
                if isfield(loaded, 'db') && isfield(loaded.db, 'cases')
                    app.HistoryTable.Data = loaded.db.cases;
                end
            end

            auditFile = fullfile(app.ProjectRoot, 'data', 'drishtisetu_audit.log');
            if isfile(auditFile)
                txt = fileread(auditFile);
                lines = splitlines(txt);
                % Show last 50 lines
                if numel(lines) > 50
                    lines = lines(end-50:end);
                end
                app.AuditTextArea.Value = lines;
            end
        end
    end
end
