% Peripheral and Core Thermal Model
%
% Sources:
%   [1] Bindu B, Bindra A, Rath G. "Temperature management under general anesthesia:
%       Compulsion or option." J Anaesthesiol Clin Pharmacol. 2017;33(3):306-316.
%       https://pmc.ncbi.nlm.nih.gov/articles/PMC5672515/
%
%   [2] Sessler DI. "Perioperative thermoregulation and heat balance."
%       Lancet. 2016;387(10038):2655-2664.
%       https://www.sciencedirect.com/science/article/abs/pii/S0031938416300622
%
%   [3] Stolwijk JAJ. "A Mathematical Model of Physiological Temperature
%       Regulation in Man." NASA Contractor Report CR-1855. Yale University /
%       NASA, 1971.
%       https://ntrs.nasa.gov/api/citations/19710023925/downloads/19710023925.pdf
%
%   [4] Fiala D, Lomas KJ, Stohrer M. "A computer model of human thermoregulation
%       for a wide range of environmental conditions: the passive system."
%       J Appl Physiol. 1999;87(5):1957-1972.
%       https://journals.physiology.org/doi/full/10.1152/jappl.1999.87.5.1957
%
%   [5] National Institute for Health and Care Excellence (NICE).
%       "Hypothermia: prevention and management in adults having surgery."
%       Clinical Guideline CG65. London: NICE; 2008 (updated December 2016).
%       Available from: https://www.nice.org.uk/guidance/cg65



% =========================================================================
% Intial Temps
% =========================================================================

Core_temp       = 37;   % deg C  -- mean core temp in healthy adults 36.5-37.3 deg C [1]
peripheral_temp = 34;   % deg C  -- periphery typically 2-4 deg C below core [1]

% =========================================================================
% Thermal Cap
% =========================================================================
% Reference man: 74.1 kg, BSA = 1.89 m^2 [3]
% Core  (~20 kg lean visceral mass)   x 3470 J/kg/deg C [3] Table 5
% Periph (~35 kg limb muscle/fat/skin) x 2500 J/kg/deg C [3][4]

C_core   = 20 * 3470;   % = 69,400 J/deg C  [3][4]
C_periph = 35 * 2500;   % = 87,500 J/deg C  [3][4]

% =========================================================================
% Metabolic heat production
% =========================================================================
% Basal resting rate from Stolwijk [3] Table 8: ~87 kcal/h = 101 W
% GA reduces metabolic rate by ~25% [2]

Q_met_awake = 101;                        % W  [3]
Q_met_GA    = Q_met_awake * (1 - 0.25);   % W  = 75.75 W  [2]

% =========================================================================
% blood flow 
% =========================================================================
% Effective core-to-peripheral conductance via blood flow [3]
% GA vasodilation abolishes tonic vasoconstriction -- ~5x increase [1][3]

k_blood_normal  = 10;   % W/deg C  -- resting / vasoconstricted  [3]
k_blood_dilated = 50;   % W/deg C  -- vasodilated under GA        [1][3]

% =========================================================================
% Ambient temp
% =========================================================================

ambient_temp = 21;   % deg C  -- standard OR temperature [1]

% =========================================================================
% skin heat loss
% =========================================================================
% BSA = 1.89 m^2 [3],  T_skin = 33 deg C,  T_amb = 21 deg C  =>  dT = 12 deg C [1][3]
% Effective exposed area under surgical draping:
%   A_eff = (10% BSA exposed to air) + (15% BSA under thin drape x 0.5) = 0.331 m^2

A_BSA   = 1.89;                                     % m^2  [3]
A_eff   = (0.10 * A_BSA) + (0.15 * A_BSA);  % = 0.331 m^2
dT_skin = 33 - ambient_temp;   %place holder for working things out                     % = 12 deg C  [1]


% Radiation:   Q = h_r x A_eff x dT,   h_r = 4.5 W/m^2/deg C  [de Dear et al. 1997, cited in 4]
w_rad   = 4.5 * A_eff * dT_skin;    % = 17.9 W

% Convection:  Q = h_c x A_eff x dT,   h_c = 3.4 W/m^2/deg C  [de Dear et al. 1997, cited in 4]
w_Conv  = 3.4 * A_eff * dT_skin;    % = 13.5 W

% Evaporation: insensible skin flux 10 g/m^2/h [3] + respiratory <10% of Q_met_GA [1]
w_Ev    = (10 * A_eff / 3600) * 2430  +  0.10 * Q_met_GA;   % = 2.2 + 7.6 = 9.8 W

% Conduction:  h = k_foam/d = 0.04/0.025 = 1.6 W/m^2/deg C, A_contact = 0.378 m^2, dT = 2 deg C  [1][3]
w_Condu = (0.04/0.025) * (0.40 * 0.50 * A_BSA) * 2;   % = 1.2 W

%core body loss
Q_loss_base = 23;  % W  -- IV fluid + cavity + airway losses  [1][2]
% =========================================================================
% Intial conditions
% =========================================================================

T_core_0   = Core_temp;        % 37 deg C  [1]
T_periph_0 = peripheral_temp;  % 34 deg C  [1]

% =========================================================================
% Timings
% =========================================================================

intial_start_of_GA=3600/2; % half an hour for the model to settle


% =========================================================================
% Onesie parameters
% =========================================================================
% NICE CG65  hypothermia core temp < 36.0 deg C [5]
% normothermia >= 36.5 deg C[5]

T_core_hypo_threshold = 36.0;   % deg C  -- hypothermia definition [5]
T_core_target = 36.5;   % deg C  -- normothermia target     [5]
T_core_max = 38.0;   % deg C  -- hyperthermia safety cut-off [5]

A_onsie=0.15; %area covered by onsie


% =========================================================================
% Heat from lungs
% =========================================================================
%  delivers gas at ambient temp, lungs warm it to T_core
% [1] Bindu et al. 2017: respiratory losses < 10% of metabolic heat
% [3] Stolwijk 1971: respiratory evaporation included in basal heat balance

V_tidal   = 0.0005;   % m^3     tidal volume, 500 ml standard adult [1]
f_resp    = 0.2;      % Hz      respiratory rate, 12 breaths/min
rho_air   = 1.2;      % kg/m^3  density of air at body temperature
c_air     = 1005;     % J/kg/C  specific heat of air
T_gas_in  = ambient_temp;  % deg C  gas delivered at OR ambient temp [1]

% Peak respiratory heat loss amplitude (W)
% Q_resp_peak = V_tidal x f x rho x c x (T_core - T_gas)
% = 0.0005 x 0.2 x 1.2 x 1005 x (37 - 21)
Q_resp_peak = V_tidal * f_resp * rho_air * c_air * (Core_temp - T_gas_in);
% = 0.0005 x 0.2 x 1.2 x 1005 x 16 = 1.93 W peak

% The sine wave oscillates between 0 and Q_resp_peak
% Use absolute sine so heat loss is always positive (no heat gain on expiration)
% Q_resp(t) = Q_resp_peak x |sin(2*pi*f_resp*t)|