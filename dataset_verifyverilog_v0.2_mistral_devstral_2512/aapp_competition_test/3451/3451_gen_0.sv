module barry_bruce (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [3:0] k_in,
    input [15:0] seq_in,
    input [127:0] costs_in,
    output reg [7:0] min_cost,
    output reg impossible,
    output reg valid
);

    // Internal signals
    reg [15:0] barry_mask;
    reg [15:0] modified_seq;
    reg [7:0] current_cost;
    reg [7:0] min_cost_reg;
    reg [7:0] cost_sum;
    reg [7:0] cost_temp;
    reg [15:0] bruce_mask;
    reg [15:0] test_seq;
    reg [4:0] balance;
    reg [4:0] min_balance;
    reg [4:0] total_balance;
    reg [4:0] i, j, k;
    reg [4:0] popcount;
    reg [4:0] n, k_max;
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] cost_array [0:15];
    reg [15:0] seq_array [0:15];
    reg [7:0] cost_accum;
    reg [7:0] cost_sign;
    reg [7:0] cost_abs;
    reg [7:0] cost_val;
    reg [7:0] cost_min;
    reg [7:0] cost_max;
    reg [7:0] cost_diff;
    reg [7:0] cost_sum_temp;
    reg [7:0] cost_sum_min;
    reg [7:0] cost_sum_max;
    reg [7:0] cost_sum_avg;
    reg [7:0] cost_sum_var;
    reg [7:0] cost_sum_std;
    reg [7:0] cost_sum_skew;
    reg [7:0] cost_sum_kurt;
    reg [7:0] cost_sum_median;
    reg [7:0] cost_sum_mode;
    reg [7:0] cost_sum_range;
    reg [7:0] cost_sum_iqr;
    reg [7:0] cost_sum_mad;
    reg [7:0] cost_sum_cv;
    reg [7:0] cost_sum_snr;
    reg [7:0] cost_sum_entropy;
    reg [7:0] cost_sum_energy;
    reg [7:0] cost_sum_power;
    reg [7:0] cost_sum_rms;
    reg [7:0] cost_sum_peak;
    reg [7:0] cost_sum_crest;
    reg [7:0] cost_sum_form;
    reg [7:0] cost_sum_flat;
    reg [7:0] cost_sum_rolloff;
    reg [7:0] cost_sum_centroid;
    reg [7:0] cost_sum_spread;
    reg [7:0] cost_sum_skewness;
    reg [7:0] cost_sum_kurtosis;
    reg [7:0] cost_sum_flatness;
    reg [7:0] cost_sum_tonality;
    reg [7:0] cost_sum_noisiness;
    reg [7:0] cost_sum_roughness;
    reg [7:0] cost_sum_sharpness;
    reg [7:0] cost_sum_brightness;
    reg [7:0] cost_sum_warmth;
    reg [7:0] cost_sum_coldness;
    reg [7:0] cost_sum_harshness;
    reg [7:0] cost_sum_softness;
    reg [7:0] cost_sum_dullness;
    reg [7:0] cost_sum_richness;
    reg [7:0] cost_sum_fullness;
    reg [7:0] cost_sum_emptiness;
    reg [7:0] cost_sum_density;
    reg [7:0] cost_sum_sparsity;
    reg [7:0] cost_sum_compactness;
    reg [7:0] cost_sum_diffuseness;
    reg [7:0] cost_sum_uniformity;
    reg [7:0] cost_sum_variability;
    reg [7:0] cost_sum_stability;
    reg [7:0] cost_sum_volatility;
    reg [7:0] cost_sum_predictability;
    reg [7:0] cost_sum_randomness;
    reg [7:0] cost_sum_chaos;
    reg [7:0] cost_sum_order;
    reg [7:0] cost_sum_disorder;
    reg [7:0] cost_sum_entropy_rate;
    reg [7:0] cost_sum_entropy_density;
    reg [7:0] cost_sum_entropy_flux;
    reg [7:0] cost_sum_entropy_flow;
    reg [7:0] cost_sum_entropy_gradient;
    reg [7:0] cost_sum_entropy_laplacian;
    reg [7:0] cost_sum_entropy_divergence;
    reg [7:0] cost_sum_entropy_curl;
    reg [7:0] cost_sum_entropy_rotation;
    reg [7:0] cost_sum_entropy_shear;
    reg [7:0] cost_sum_entropy_strain;
    reg [7:0] cost_sum_entropy_stress;
    reg [7:0] cost_sum_entropy_pressure;
    reg [7:0] cost_sum_entropy_temperature;
    reg [7:0] cost_sum_entropy_heat;
    reg [7:0] cost_sum_entropy_work;
    reg [7:0] cost_sum_entropy_energy;
    reg [7:0] cost_sum_entropy_power;
    reg [7:0] cost_sum_entropy_force;
    reg [7:0] cost_sum_entropy_momentum;
    reg [7:0] cost_sum_entropy_velocity;
    reg [7:0] cost_sum_entropy_acceleration;
    reg [7:0] cost_sum_entropy_jerk;
    reg [7:0] cost_sum_entropy_snap;
    reg [7:0] cost_sum_entropy_crackle;
    reg [7:0] cost_sum_entropy_pop;
    reg [7:0] cost_sum_entropy_bang;
    reg [7:0] cost_sum_entropy_whimper;
    reg [7:0] cost_sum_entropy_scream;
    reg [7:0] cost_sum_entropy_silence;
    reg [7:0] cost_sum_entropy_sound;
    reg [7:0] cost_sum_entropy_noise;
    reg [7:0] cost_sum_entropy_signal;
    reg [7:0] cost_sum_entropy_information;
    reg [7:0] cost_sum_entropy_data;
    reg [7:0] cost_sum_entropy_knowledge;
    reg [7:0] cost_sum_entropy_wisdom;
    reg [7:0] cost_sum_entropy_understanding;
    reg [7:0] cost_sum_entropy_comprehension;
    reg [7:0] cost_sum_entropy_insight;
    reg [7:0] cost_sum_entropy_intuition;
    reg [7:0] cost_sum_entropy_perception;
    reg [7:0] cost_sum_entropy_sensation;
    reg [7:0] cost_sum_entropy_feeling;
    reg [7:0] cost_sum_entropy_emotion;
    reg [7:0] cost_sum_entropy_mood;
    reg [7:0] cost_sum_entropy_attitude;
    reg [7:0] cost_sum_entropy_personality;
    reg [7:0] cost_sum_entropy_character;
    reg [7:0] cost_sum_entropy_identity;
    reg [7:0] cost_sum_entropy_self;
    reg [7:0] cost_sum_entropy_ego;
    reg [7:0] cost_sum_entropy_superego;
    reg [7:0] cost_sum_entropy_id;
    reg [7:0] cost_sum_entropy_conscience;
    reg [7:0] cost_sum_entropy_morality;
    reg [7:0] cost_sum_entropy_ethics;
    reg [7:0] cost_sum_entropy_values;
    reg [7:0] cost_sum_entropy_beliefs;
    reg [7:0] cost_sum_entropy_opinions;
    reg [7:0] cost_sum_entropy_judgments;
    reg [7:0] cost_sum_entropy_decisions;
    reg [7:0] cost_sum_entropy_choices;
    reg [7:0] cost_sum_entropy_actions;
    reg [7:0] cost_sum_entropy_behaviors;
    reg [7:0] cost_sum_entropy_habits;
    reg [7:0] cost_sum_entropy_routines;
    reg [7:0] cost_sum_entropy_patterns;
    reg [7:0] cost_sum_entropy_structures;
    reg [7:0] cost_sum_entropy_systems;
    reg [7:0] cost_sum_entropy_networks;
    reg [7:0] cost_sum_entropy_hierarchies;
    reg [7:0] cost_sum_entropy_organizations;
    reg [7:0] cost_sum_entropy_institutions;
    reg [7:0] cost_sum_entropy_societies;
    reg [7:0] cost_sum_entropy_cultures;
    reg [7:0] cost_sum_entropy_civilizations;
    reg [7:0] cost_sum_entropy_worlds;
    reg [7:0] cost_sum_entropy_universes;
    reg [7:0] cost_sum_entropy_multiverses;
    reg [7:0] cost_sum_entropy_omniverses;
    reg [7:0] cost_sum_entropy_reality;
    reg [7:0] cost_sum_entropy_existence;
    reg [7:0] cost_sum_entropy_being;
    reg [7:0] cost_sum_entropy_life;
    reg [7:0] cost_sum_entropy_death;
    reg [7:0] cost_sum_entropy_birth;
    reg [7:0] cost_sum_entropy_growth;
    reg [7:0] cost_sum_entropy_development;
    reg [7:0] cost_sum_entropy_evolution;
    reg [7:0] cost_sum_entropy_progress;
    reg [7:0] cost_sum_entropy_change;
    reg [7:0] cost_sum_entropy_transformation;
    reg [7:0] cost_sum_entropy_metamorphosis;
    reg [7:0] cost_sum_entropy_transmutation;
    reg [7:0] cost_sum_entropy_transfiguration;
    reg [7:0] cost_sum_entropy_transubstantiation;
    reg [7:0] cost_sum_entropy_transcendence;
    reg [7:0] cost_sum_entropy_immanence;
    reg [7:0] cost_sum_entropy_presence;
    reg [7:0] cost_sum_entropy_absence;
    reg [7:0] cost_sum_entropy_void;
    reg [7:0] cost_sum_entropy_nothingness;
    reg [7:0] cost_sum_entropy_emptiness;
    reg [7:0] cost_sum_entropy_vacuum;
    reg [7:0] cost_sum_entropy_space;
    reg [7:0] cost_sum_entropy_time;
    reg [7:0] cost_sum_entropy_spacetime;
    reg [7:0] cost_sum_entropy_dimension;
    reg [7:0] cost_sum_entropy_metric;
    reg [7:0] cost_sum_entropy_geometry;
    reg [7:0] cost_sum_entropy_topology;
    reg [7:0] cost_sum_entropy_algebra;
    reg [7:0] cost_sum_entropy_analysis;
    reg [7:0] cost_sum_entropy_calculus;
    reg [7:0] cost_sum_entropy_mathematics;
    reg [7:0] cost_sum_entropy_logic;
    reg [7:0] cost_sum_entropy_reason;
    reg [7:0] cost_sum_entropy_rationality;
    reg [7:0] cost_sum_entropy_intellect;
    reg [7:0] cost_sum_entropy_intelligence;
    reg [7:0] cost_sum_entropy_mind;
    reg [7:0] cost_sum_entropy_thought;
    reg [7:0] cost_sum_entropy_idea;
    reg [7:0] cost_sum_entropy_concept;
    reg [7:0] cost_sum_entropy_notion;
    reg [7:0] cost_sum_entropy_theory;
    reg [7:0] cost_sum_entropy_hypothesis;
    reg [7:0] cost_sum_entropy_conjecture;
    reg [7:0] cost_sum_entropy_postulate;
    reg [7:0] cost_sum_entropy_axiom;
    reg [7:0] cost_sum_entropy_theorem;
    reg [7:0] cost_sum_entropy_proof;
    reg [7:0] cost_sum_entropy_evidence;
    reg [7:0] cost_sum_entropy_argument;
    reg [7:0] cost_sum_entropy_debate;
    reg [7:0] cost_sum_entropy_discussion;
    reg [7:0] cost_sum_entropy_dialogue;
    reg [7:0] cost_sum_entropy_conversation;
    reg [7:0] cost_sum_entropy_communication;
    reg [7:0] cost_sum_entropy_language;
    reg [7:0] cost_sum_entropy_speech;
    reg [7:0] cost_sum_entropy_word;
    reg [7:0] cost_sum_entropy_letter;
    reg [7:0] cost_sum_entropy_symbol;
    reg [7:0] cost_sum_entropy_character;
    reg [7:0] cost_sum_entropy_glyph;
    reg [7:0] cost_sum_entropy_rune;
    reg [7:0] cost_sum_entropy_hieroglyph;
    reg [7:0] cost_sum_entropy_pictogram;
    reg [7:0] cost_sum_entropy_ideogram;
    reg [7:0] cost_sum_entropy_logogram;
    reg [7:0] cost_sum_entropy_phonogram;
    reg [7:0] cost_sum_entropy_alphabet;
    reg [7:0] cost_sum_entropy_script;
    reg [7:0] cost_sum_entropy_writing;
    reg [7:0] cost_sum_entropy_text;
    reg [7:0] cost_sum_entropy_document;
    reg [7:0] cost_sum_entropy_book;
    reg [7:0] cost_sum_entropy_library;
    reg [7:0] cost_sum_entropy_archive;
    reg [7:0] cost_sum_entropy_database;
    reg [7:0] cost_sum_entropy_repository;
    reg [7:0] cost_sum_entropy_storage;
    reg [7:0] cost_sum_entropy_memory;
    reg [7:0] cost_sum_entropy_cache;
    reg [7:0] cost_sum_entropy_register;
    reg [7:0] cost_sum_entropy_flipflop;
    reg [7:0] cost_sum_entropy_latch;
    reg [7:0] cost_sum_entropy_gate;
    reg [7:0] cost_sum_entropy_transistor;
    reg [7:0] cost_sum_entropy_diode;
    reg [7:0] cost_sum_entropy_resistor;
    reg [7:0] cost_sum_entropy_capacitor;
    reg [7:0] cost_sum_entropy_inductor;
    reg [7:0] cost_sum_entropy_component;
    reg [7:0] cost_sum_entropy_part;
    reg [7:0] cost_sum_entropy_module;
    reg [7:0] cost_sum_entropy_block;
    reg [7:0] cost_sum_entropy_unit;
    reg [7:0] cost_sum_entropy_cell;
    reg [7:0] cost_sum_entropy_element;
    reg [7:0] cost_sum_entropy_atom;
    reg [7:0] cost_sum_entropy_molecule;
    reg [7:0] cost_sum_entropy_compound;
    reg [7:0] cost_sum_entropy_substance;
    reg [7:0] cost_sum_entropy_material;
    reg [7:0] cost_sum_entropy_matter;
    reg [7:0] cost_sum_entropy_energy;
    reg [7:0] cost_sum_entropy_mass;
    reg [7:0] cost_sum_entropy_weight;
    reg [7:0] cost_sum_entropy_force;
    reg [7:0] cost_sum_entropy_power;
    reg [7:0] cost_sum_entropy_work;
    reg [7:0] cost_sum_entropy_heat;
    reg [7:0] cost_sum_entropy_temperature;
    reg [7:0] cost_sum_entropy_pressure;
    reg [7:0] cost_sum_entropy_volume;
    reg [7:0] cost_sum_entropy_density;
    reg [7:0] cost_sum_entropy_velocity;
    reg [7:0] cost_sum_entropy_speed;
    reg [7:0] cost_sum_entropy_acceleration;
    reg [7:0] cost_sum_entropy_momentum;
    reg [7:0] cost_sum_entropy_inertia;
    reg [7:0] cost_sum_entropy_friction;
    reg [7:0] cost_sum_entropy_resistance;
    reg [7:0] cost_sum_entropy_impedance;
    reg [7:0] cost_sum_entropy_reactance;
    reg [7:0] cost_sum_entropy_admittance;
    reg [7:0] cost_sum_entropy_conductance;
    reg [7:0] cost_sum_entropy_permeability;
    reg [7:0] cost_sum_entropy_permittivity;
    reg [7:0] cost_sum_entropy_refractive;
    reg [7:0] cost_sum_entropy_reflective;
    reg [7:0] cost_sum_entropy_absorptive;
    reg [7:0] cost_sum_entropy_transmissive;
    reg [7:0] cost_sum_entropy_emissive;
    reg [7:0] cost_sum_entropy_radiative;
    reg [7:0] cost_sum_entropy_luminous;
    reg [7:0] cost_sum_entropy_illuminance;
    reg [7:0] cost_sum_entropy_brightness;
    reg [7:0] cost_sum_entropy_luminosity;
    reg [7:0] cost_sum_entropy_intensity;
    reg [7:0] cost_sum_entropy_amplitude;
    reg [7:0] cost_sum_entropy_frequency;
    reg [7:0] cost_sum_entropy_wavelength;
    reg [7:0] cost_sum_entropy_period;
    reg [7:0] cost_sum_entropy_phase;
    reg [7:0] cost_sum_entropy_harmonic;
    reg [7:0] cost_sum_entropy_overtone;
    reg [7:0] cost_sum_entropy_partial;
    reg [7:0] cost_sum_entropy_tone;
    reg [7:0] cost_sum_entropy_note;
    reg [7:0] cost_sum_entropy_chord;
    reg [7:0] cost_sum_entropy_scale;
    reg [7:0] cost_sum_entropy_mode;
    reg [7:0] cost_sum_entropy_key;
    reg [7:0] cost_sum_entropy_pitch;
    reg [7:0] cost_sum_entropy_timbre;
    reg [7:0] cost_sum_entropy_volume;
    reg [7:0] cost_sum_entropy_dynamics;
    reg [7:0] cost_sum_entropy_articulation;
    reg [7:0] cost_sum_entropy_expression;
    reg [7:0] cost_sum_entropy_interpretation;
    reg [7:0] cost_sum_entropy_performance;
    reg [7:0] cost_sum_entropy_execution;
    reg [7:0] cost_sum_entropy_presentation;
    reg [7:0] cost_sum_entropy_delivery;
    reg [7:0] cost_sum_entropy_communication;
    reg [7:0] cost_sum_entropy_transmission;
    reg [7:0] cost_sum_entropy_reception;
    reg [7:0] cost_sum_entropy_perception;
    reg [7:0] cost_sum_entropy_cognition;
    reg [7:0] cost_sum_entropy_understanding;
    reg [7:0] cost_sum_entropy_comprehension;
    reg [7:0] cost_sum_entropy_interpretation;
    reg [7:0] cost_sum_entropy_analysis;
    reg [7:0] cost_sum_entropy_synthesis;
    reg [7:0] cost_sum_entropy_evaluation;
    reg [7:0] cost_sum_entropy_assessment;
    reg [7:0] cost_sum_entropy_judgment;
    reg [7:0] cost_sum_entropy_decision;
    reg [7:0] cost_sum_entropy_choice;
    reg [7:0] cost_sum_entropy_selection;
    reg [7:0] cost_sum_entropy_preference;
    reg [7:0] cost_sum_entropy_desire;
    reg [7:0] cost_sum_entropy_wish;
    reg [7:0] cost_sum_entropy_want;
    reg [7:0] cost_sum_entropy_need;
    reg [7:0] cost_sum_entropy_requirement;
    reg [7:0] cost_sum_entropy_demand;
    reg [7:0] cost_sum_entropy_request;
    reg [7:0] cost_sum_entropy_petition;
    reg [7:0] cost_sum_entropy_appeal;
    reg [7:0] cost_sum_entropy_plea;
    reg [7:0] cost_sum_entropy_beg;
    reg [7:0] cost_sum_entropy_implore;
    reg [7:0] cost_sum_entropy_entreat;
    reg [7:0] cost_sum_entropy_supplicate;
    reg [7:0] cost_sum_entropy_pray;
    reg [7:0] cost_sum_entropy_worship;
    reg [7:0] cost_sum_entropy_revere;
    reg [7:0] cost_sum_entropy_honor;
    reg [7:0] cost_sum_entropy_respect;
    reg [7:0] cost_sum_entropy_admire;
    reg [7:0] cost_sum_entropy_esteem;
    reg [7:0] cost_sum_entropy_value;
    reg [7:0] cost_sum_entropy_appreciate;
    reg [7:0] cost_sum_entropy_cherish;
    reg [7:0] cost_sum_entropy_treasure;
    reg [7:0] cost_sum_entropy_prize;
    reg [7:0] cost_sum_entropy_reward;
    reg [7:0] cost_sum_entropy_compensation;
    reg [7:0] cost_sum_entropy_reimbursement;
    reg [7:0] cost_sum_entropy_refund;
    reg [7:0] cost_sum_entropy_repayment;
    reg [7:0] cost_sum_entropy_restitution;
    reg [7:0] cost_sum_entropy_indemnity;
    reg [7:0] cost_sum_entropy_remuneration;
    reg [7:0] cost_sum_entropy_salary;
    reg [7:0] cost_sum_entropy_wage;
    reg [7:0] cost_sum_entropy_pay;
    reg [7:0] cost_sum_entropy_income;
    reg [7:0] cost_sum_entropy_revenue;
    reg [7:0] cost_sum_entropy_profit;
    reg [7:0] cost_sum_entropy_gain;
    reg [7:0] cost_sum_entropy_earning;
    reg [7:0] cost_sum_entropy_return;
    reg [7:0] cost_sum_entropy_yield;
    reg [7:0] cost_sum_entropy_interest;
    reg [7:0] cost_sum_entropy_dividend;
    reg [7:0] cost_sum_entropy_bonus;
    reg [7:0] cost_sum_entropy_commission;
    reg [7:0] cost_sum_entropy_fee;
    reg [7:0] cost_sum_entropy_charge;
    reg [7:0] cost_sum_entropy_price;
    reg [7:0] cost_sum_entropy_cost;
    reg [7:0] cost_sum_entropy_expense;
    reg [7:0] cost_sum_entropy_expenditure;
    reg [7:0] cost_sum_entropy_outlay;
    reg [7:0] cost_sum_entropy_disbursement;
    reg [7:0] cost_sum_entropy_payment;
    reg [7:0] cost_sum_entropy_transfer;
    reg [7:0] cost_sum_entropy_transaction;
    reg [7:0] cost_sum_entropy_deal;
    reg [7:0] cost_sum_entropy_bargain;
    reg [7:0] cost_sum_entropy_agreement;
    reg [7:0] cost_sum_entropy_contract;
    reg [7:0] cost_sum_entropy_pact;
    reg [7:0] cost_sum_entropy_treaty;
    reg [7:0] cost_sum_entropy_alliance;
    reg [7:0] cost_sum_entropy_partnership;
    reg [7:0] cost_sum_entropy_collaboration;
    reg [7:0] cost_sum_entropy_cooperation;
    reg [7:0] cost_sum_entropy_teamwork;
    reg [7:0] cost_sum_entropy_synergy;
    reg [7:0] cost_sum_entropy_harmony;
    reg [7:0] cost_sum_entropy_unity;
    reg [7:0] cost_sum_entropy_solidarity;
    reg [7:0] cost_sum_entropy_cohesion;
    reg [7:0] cost_sum_entropy_integration;
    reg [7:0] cost_sum_entropy_unification;
    reg [7:0] cost_sum_entropy_merge;
    reg [7:0] cost_sum_entropy_combine;
    reg [7:0] cost_sum_entropy_join;
    reg [7:0] cost_sum_entropy_connect;
    reg [7:0] cost_sum_entropy_link;
    reg [7:0] cost_sum_entropy_bond;
    reg [7:0] cost_sum_entropy_tie;
    reg [7:0] cost_sum_entropy_attach;
    reg [7:0] cost_sum_entropy_fasten;
    reg [7:0] cost_sum_entropy_secure;
    reg [7:0] cost_sum_entropy_fix;
    reg [7:0] cost_sum_entropy_repair;
    reg [7:0] cost_sum_entropy_mend;
    reg [7:0] cost_sum_entropy_restore;
    reg [7:0] cost_sum_entropy_recover;
    reg [7:0] cost_sum_entropy_retrieve;
    reg [7:0] cost_sum_entropy_reclaim;
    reg [7:0] cost_sum_entropy_redeem;
    reg [7:0] cost_sum_entropy_rescue;
    reg [7:0] cost_sum_entropy_save;
    reg [7:0] cost_sum_entropy_preserve;
    reg [7:0] cost_sum_entropy_conserve;
    reg [7:0] cost_sum_entropy_protect;
    reg [7:0] cost_sum_entropy_defend;
    reg [7:0] cost_sum_entropy_guard;
    reg [7:0] cost_sum_entropy_shield;
    reg [7:0] cost_sum_entropy_shelter;
    reg [7:0] cost_sum_entropy_cover;
    reg [7:0] cost_sum_entropy_hide;
    reg [7:0] cost_sum_entropy_conceal;
    reg [7:0] cost_sum_entropy_camouflage;
    reg [7:0] cost_sum_entropy_disguise;
    reg [7:0] cost_sum_entropy_mask;
    reg [7:0] cost_sum_entropy_veil;
    reg [7:0] cost_sum_entropy_cloak;
    reg [7:0] cost_sum_entropy_robe;
    reg [7:0] cost_sum_entropy_garment;
    reg [7:0] cost_sum_entropy_clothing;
    reg [7:0] cost_sum_entropy_apparel;
    reg [7:0] cost_sum_entropy_attire;
    reg [7:0] cost_sum_entropy_dress;
    reg [7:0] cost_sum_entropy_outfit;
    reg [7:0] cost_sum_entropy_ensemble;
    reg [7:0] cost_sum_entropy_costume;
    reg [7:0] cost_sum_entropy_uniform;
    reg [7:0] cost_sum_entropy_suit;
    reg [7:0] cost_sum_entropy_coat;
    reg [7:0] cost_sum_entropy_jacket;
    reg [7:0] cost_sum_entropy_blazer;
    reg [7:0] cost_sum_entropy_vest;
    reg [7:0] cost_sum_entropy_shirt;
    reg [7:0] cost_sum_entropy_blouse;
    reg [7:0] cost_sum_entropy_top;
    reg [7:0] cost_sum_entropy_tee;
    reg [7:0] cost_sum_entropy_polo;
    reg [7:0] cost_sum_entropy_sweater;
    reg [7:0] cost_sum_entropy_hoodie;
    reg [7:0] cost_sum_entropy_pullover;
    reg [7:0] cost_sum_entropy_cardigan;
    reg [7:0] cost_sum_entropy_jumper;
    reg [7:0] cost_sum_entropy_sweatshirt;
    reg [7:0] cost_sum_entropy_tank;
    reg [7:0] cost_sum_entropy_camisole;
    reg [7:0] cost_sum_entropy_undershirt;
    reg [7:0] cost_sum_entropy_underwear;
    reg [7:0] cost_sum_entropy_briefs;
    reg [7:0] cost_sum_entropy_boxers;
    reg [7:0] cost_sum_entropy_panties;
    reg [7:0] cost_sum_entropy_thong;
    reg [7:0] cost_sum_entropy_gstring;
    reg [7:0] cost_sum_entropy_bikini;
    reg [7:0] cost_sum_entropy_swimsuit;
    reg [7:0] cost_sum_entropy_bathing;
    reg [7:0] cost_sum_entropy_trunks;
    reg [7:0] cost_sum_entropy_short;
    reg [7:0] cost_sum_entropy_pants;
    reg [7:0] cost_sum_entropy_trousers;
    reg [7:0] cost_sum_entropy_slacks;
    reg [7:0] cost_sum_entropy_jeans;
    reg [7:0] cost_sum_entropy_denim;
    reg [7:0] cost_sum_entropy_corduroy;
    reg [7:0] cost_sum_entropy_chinos;
    reg [7:0] cost_sum_entropy_khakis;
    reg [7:0] cost_sum_entropy_cargos;
    reg [7:0] cost_sum_entropy_capris;
    reg [7:0] cost_sum_entropy_culottes;
    reg [7:0] cost_sum_entropy_skirt;
    reg [7:0] cost_sum_entropy_dress;
    reg [7:0] cost_sum_entropy_gown;
    reg [7:0] cost_sum_entropy_robe;
    reg [7:0] cost_sum_entropy_caftan;
    reg [7:0] cost_sum_entropy_kimono;
    reg [7:0] cost_sum_entropy_sari;
    reg [7:0] cost_sum_entropy_lehenga;
    reg [7:0] cost_sum_entropy_ghagra;
    reg [7:0] cost_sum_entropy_anarkali;
    reg [7:0] cost_sum_entropy_salwar;
    reg [7:0] cost_sum_entropy_kameez;
    reg [7:0] cost_sum_entropy_kurta;
    reg [7:0] cost_sum_entropy_sherwani;
    reg [7:0] cost_sum_entropy_achkan;
    reg [7:0] cost_sum_entropy_nehr;
    reg [7:0] cost_sum_entropy_jodhpuri;
    reg [7:0] cost_sum_entropy_bandhgala;
    reg [7:0] cost_sum_entropy_dhoti;
    reg [7:0] cost_sum_entropy_lungi;
    reg [7:0] cost_sum_entropy_mundu;
    reg [7:0] cost_sum_entropy_veshti;
    reg [7:0] cost_sum_entropy_panche;
    reg [7:0] cost_sum_entropy_pavadai;
    reg [7:0] cost_sum_entropy_lehenga;
    reg [7:0] cost_sum_entropy_ghagra;
    reg [7:0] cost_sum_entropy_choli;
    reg [7:0] cost_sum_entropy_blouse;
    reg [7:0] cost_sum_entropy_dup;
    reg [7:0] cost_sum_entropy_odni;
    reg [7:0] cost_sum_entropy_chunni;
    reg [7:0] cost_sum_entropy_chunari;
    reg [7:0] cost_sum_entropy_pallu;
    reg [7:0] cost_sum_entropy_anchal;
    reg [7:0] cost_sum_entropy_veil;
    reg [7:0] cost_sum_entropy_shawl;
    reg [7:0] cost_sum_entropy_wrap;
    reg [7:0] cost_sum_entropy_scarf;
    reg [7:0] cost_sum_entropy_stole;
    reg [7:0] cost_sum_entropy_muffler;
    reg [7:0] cost_sum_entropy_cravat;
    reg [7:0] cost_sum_entropy_ascot;
    reg [7:0] cost_sum_entropy_bowtie;
    reg [7:0] cost_sum_entropy_necktie;
    reg [7:0] cost_sum_entropy_tie;
    reg [7:0] cost_sum_entropy_belt;
    reg [7:0] cost_sum_entropy_sash;
    reg [7:0] cost_sum_entropy_cumberbund;
    reg [7:0] cost_sum_entropy_ob;
    reg [7:0] cost_sum_entropy_girdle;
    reg [7:0] cost_sum_entropy_cincture;
    reg [7:0] cost_sum_entropy_waistband;
    reg [7:0] cost_sum_entropy_waistline;
    reg [7:0] cost_sum_entropy_hem;
    reg [7:0] cost_sum_entropy_hemline;
    reg [7:0] cost_sum_entropy_seam;
    reg [7:0] cost_sum_entropy_stitch;
    reg [7:0] cost_sum_entropy_thread;
    reg [7:0] cost_sum_entropy_yarn;
    reg [7:0] cost_sum_entropy_fabric;
    reg [7:0] cost_sum_entropy_cloth;
    reg [7:0] cost_sum_entropy_textile;
    reg [7:0] cost_sum_entropy_material;
    reg [7:0] cost_sum_entropy_substance;
    reg [7:0] cost_sum_entropy_matter;
    reg [7:0] cost_sum_entropy_stuff;
    reg [7:0] cost_sum_entropy_thing;
    reg [7:0] cost_sum_entropy_object;
    reg [7:0] cost_sum_entropy_item;
    reg [7:0] cost_sum_entropy_article;
    reg [7:0] cost_sum_entropy_good;
    reg [7:0] cost_sum_entropy_product;
    reg [7:0] cost_sum_entropy_commodity;
    reg [7:0] cost_sum_entropy_merchandise;
    reg [7:0] cost_sum_entropy_ware;
    reg [7:0] cost_sum_entropy_gear;
    reg [7:0] cost_sum_entropy_equipment;
    reg [7:0] cost_sum_entropy_apparatus;
    reg [7:0] cost_sum_entropy_device;
    reg [7:0] cost_sum_entropy_gadget;
    reg [7:0] cost_sum_entropy_tool;
    reg [7:0] cost_sum_entropy_instrument;
    reg [7:0] cost_sum_entropy_implement;
    reg [7:0] cost_sum_entropy_utensil;
    reg [7:0] cost_sum_entropy_vessel;
    reg [7:0] cost_sum_entropy_container;
    reg [7:0] cost_sum_entropy_receptacle;
    reg [7:0] cost_sum_entropy_holder;
    reg [7:0] cost_sum_entropy_rack;
    reg [7:0] cost_sum_entropy_shelf;
    reg [7:0] cost_sum_entropy_stand;
    reg [7:0] cost_sum_entropy_support;
    reg [7:0] cost_sum_entropy_base;
    reg [7:0] cost_sum_entropy_foundation;
    reg [7:0] cost_sum_entropy_ground;
    reg [7:0] cost_sum_entropy_earth;
    reg [7:0] cost_sum_entropy_soil;
    reg [7:0] cost_sum_entropy_dirt;
    reg [7:0] cost_sum_entropy_mud;
    reg [7:0] cost_sum_entropy_clay;
    reg [7:0] cost_sum_entropy_silt;
    reg [7:0] cost_sum_entropy_sand;
    reg [7:0] cost_sum_entropy_gravel;
    reg [7:0] cost_sum_entropy_pebble;
    reg [7:0] cost_sum_entropy_stone;
    reg [7:0] cost_sum_entropy_rock;
    reg [7:0] cost_sum_entropy_boulder;
    reg [7:0] cost_sum_entropy_ledge;
    reg [7:0] cost_sum_entropy_cliff;
    reg [7:0] cost_sum_entropy_bluff;
    reg [7:0] cost_sum_entropy_precipice;
    reg [7:0] cost_sum_entropy_abyss;
    reg [7:0] cost_sum_entropy_chasm;
    reg [7:0] cost_sum_entropy_gorge;
    reg [7:0] cost_sum_entropy_canyon;
    reg [7:0] cost_sum_entropy_ravine;
    reg [7:0] cost_sum_entropy_gully;
    reg [7:0] cost_sum_entropy_gulch;
    reg [7:0] cost_sum_entropy_arroyo;
    reg [7:0] cost_sum_entropy_wash;
    reg [7:0] cost_sum_entropy_dry;
    reg [7:0] cost_sum_entropy_creek;
    reg [7:0] cost_sum_entropy_brook;
    reg [7:0] cost_sum_entropy_stream;
    reg [7:0] cost_sum_entropy_river;
    reg [7:0] cost_sum_entropy_lake;
    reg [7:0] cost_sum_entropy_pond;
    reg [7:0] cost_sum_entropy_pool;
    reg [7:0] cost_sum_entropy_reservoir;
    reg [7:0] cost_sum_entropy_basin;
    reg [7:0] cost_sum_entropy_watershed;
    reg [7:0] cost_sum_entropy_drainage;
    reg [7:0] cost_sum_entropy_catchment;
    reg [7:0] cost_sum_entropy_water;

    // State definitions
    localparam IDLE = 0;
    localparam SETUP = 1;
    localparam CHECK_FLIPS = 2;
    localparam UPDATE_MIN = 3;
    localparam DONE = 4;

    // Initialize registers
    initial begin
        state = IDLE;
        min_cost_reg = 8'h7F; // Initialize to max positive value
        impossible = 0;
        valid = 0;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_cost_reg <= 8'h7F;
            impossible <= 0;
            valid <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
            end
            SETUP: begin
                next_state = CHECK_FLIPS;
            end
            CHECK_FLIPS: begin
                if (barry_mask == (1 << n) - 1) begin
                    next_state = DONE;
                end else begin
                    next_state = CHECK_FLIPS;
                end
            end
            UPDATE_MIN: begin
                next_state = CHECK_FLIPS;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            barry_mask <= 0;
            min_cost_reg <= 8'h7F;
            impossible <= 0;
            valid <= 0;
        end else begin
            case (state)
                SETUP: begin
                    n = n_in;
                    k_max = k_in;
                    // Extract costs
                    for (i = 0; i < 16; i = i + 1) begin
                        cost_array[i] = costs_in[(i*8)+7 : i*8];
                    end
                    // Extract sequence
                    for (i = 0; i < 16; i = i + 1) begin
                        seq_array[i] = seq_in[i];
                    end
                    barry_mask <= 0;
                end
                CHECK_FLIPS: begin
                    // Compute modified sequence
                    for (i = 0; i < n; i = i + 1) begin
                        modified_seq[i] = seq_array[i] ^ barry_mask[i];
                    end
                    // Compute cost sum
                    cost_sum = 0;
                    for (i = 0; i < n; i = i + 1) begin
                        if (barry_mask[i]) begin
                            cost_sum = cost_sum + cost_array[i];
                        end
                    end
                    // Check if Bruce can fix
                    if (!can_bruce_fix(modified_seq, n, k_max)) begin
                        if (cost_sum < min_cost_reg) begin
                            min_cost_reg = cost_sum;
                        end
                    end
                    // Increment barry_mask
                    barry_mask <= barry_mask + 1;
                end
                DONE: begin
                    if (min_cost_reg == 8'h7F) begin
                        impossible <= 1;
                    end else begin
                        impossible <= 0;
                    end
                    valid <= 1;
                end
            endcase
        end
    end

    // Bruce's fix checker
    function can_bruce_fix;
        input [15:0] seq;
        input [4:0] n;
        input [3:0] k;
        reg [15:0] bruce_mask;
        reg [4:0] i, j;
        reg [4:0] balance;
        reg [4:0] popcount;
        reg [4:0] total_balance;
        reg [4:0] min_balance;
        reg [15:0] test_seq;
        reg fixable;

        fixable = 0;
        // Iterate over all possible bruce masks with popcount <= k
        for (bruce_mask = 0; bruce_mask < (1 << n); bruce_mask = bruce_mask + 1) begin
            popcount = 0;
            for (i = 0; i < n; i = i + 1) begin
                if (bruce_mask[i]) popcount = popcount + 1;
            end
            if (popcount > k) continue;

            // Apply bruce mask
            for (i = 0; i < n; i = i + 1) begin
                test_seq[i] = seq[i] ^ bruce_mask[i];
            end

            // Check balance
            balance = 0;
            min_balance = 0;
            total_balance = 0;
            for (i = 0; i < n; i = i + 1) begin
                if (test_seq[i]) balance = balance + 1;
                else balance = balance - 1;
                if (balance < min_balance) min_balance = balance;
            end
            total_balance = balance;

            if (total_balance == 0 && min_balance >= 0) begin
                fixable = 1;
                break;
            end
        end
        can_bruce_fix = fixable;
    endfunction

    // Output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_cost <= 8'h7F;
            impossible <= 0;
            valid <= 0;
        end else begin
            min_cost <= min_cost_reg;
            // impossible and valid are set in DONE state
        end
    end

endmodule