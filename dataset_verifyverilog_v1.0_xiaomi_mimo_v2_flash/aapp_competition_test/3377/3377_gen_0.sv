module peg_planner #(
    parameter MAX_N = 4,
    parameter MAX_STEPS = 8,
    parameter MAX_WET_STEPS = 32,
    parameter DATA_WIDTH = 4,
    parameter DEP_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [DATA_WIDTH-1:0] point_id,
    input wire [DEP_WIDTH-1:0] dep_mask,
    input wire dep_valid,
    
    input wire signed [DATA_WIDTH:0] dry_step,
    input wire dry_valid,
    
    output reg signed [DATA_WIDTH:0] wet_step,
    output reg wet_valid,
    output reg done,
    output reg possible
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] LOAD_DEPS = 3'd1;
localparam [2:0] LOAD_DRY = 3'd2;
localparam [2:0] PROCESS = 3'd3;
localparam [2:0] OUTPUT = 3'd4;
localparam [2:0] COMPLETE = 3'd5;

reg [2:0] current_state, next_state;

reg [DEP_WIDTH-1:0] deps_0;
reg [DEP_WIDTH-1:0] deps_1;
reg [DEP_WIDTH-1:0] deps_2;
reg [DEP_WIDTH-1:0] deps_3;
reg [DEP_WIDTH-1:0] deps_4;

reg signed [DATA_WIDTH:0] dry_plan_0;
reg signed [DATA_WIDTH:0] dry_plan_1;
reg signed [DATA_WIDTH:0] dry_plan_2;
reg signed [DATA_WIDTH:0] dry_plan_3;
reg signed [DATA_WIDTH:0] dry_plan_4;
reg signed [DATA_WIDTH:0] dry_plan_5;
reg signed [DATA_WIDTH:0] dry_plan_6;
reg signed [DATA_WIDTH:0] dry_plan_7;

reg signed [DATA_WIDTH:0] wet_plan_0;
reg signed [DATA_WIDTH:0] wet_plan_1;
reg signed [DATA_WIDTH:0] wet_plan_2;
reg signed [DATA_WIDTH:0] wet_plan_3;
reg signed [DATA_WIDTH:0] wet_plan_4;
reg signed [DATA_WIDTH:0] wet_plan_5;
reg signed [DATA_WIDTH:0] wet_plan_6;
reg signed [DATA_WIDTH:0] wet_plan_7;
reg signed [DATA_WIDTH:0] wet_plan_8;
reg signed [DATA_WIDTH:0] wet_plan_9;
reg signed [DATA_WIDTH:0] wet_plan_10;
reg signed [DATA_WIDTH:0] wet_plan_11;
reg signed [DATA_WIDTH:0] wet_plan_12;
reg signed [DATA_WIDTH:0] wet_plan_13;
reg signed [DATA_WIDTH:0] wet_plan_14;
reg signed [DATA_WIDTH:0] wet_plan_15;
reg signed [DATA_WIDTH:0] wet_plan_16;
reg signed [DATA_WIDTH:0] wet_plan_17;
reg signed [DATA_WIDTH:0] wet_plan_18;
reg signed [DATA_WIDTH:0] wet_plan_19;
reg signed [DATA_WIDTH:0] wet_plan_20;
reg signed [DATA_WIDTH:0] wet_plan_21;
reg signed [DATA_WIDTH:0] wet_plan_22;
reg signed [DATA_WIDTH:0] wet_plan_23;
reg signed [DATA_WIDTH:0] wet_plan_24;
reg signed [DATA_WIDTH:0] wet_plan_25;
reg signed [DATA_WIDTH:0] wet_plan_26;
reg signed [DATA_WIDTH:0] wet_plan_27;
reg signed [DATA_WIDTH:0] wet_plan_28;
reg signed [DATA_WIDTH:0] wet_plan_29;
reg signed [DATA_WIDTH:0] wet_plan_30;
reg signed [DATA_WIDTH:0] wet_plan_31;

reg [DEP_WIDTH-1:0] history_0;
reg [DEP_WIDTH-1:0] history_1;
reg [DEP_WIDTH-1:0] history_2;
reg [DEP_WIDTH-1:0] history_3;
reg [DEP_WIDTH-1:0] history_4;

reg [DEP_WIDTH-1:0] current_pegs;

reg [3:0] dep_idx;
reg [3:0] dry_idx;
reg [3:0] dry_ptr;
reg [5:0] wet_idx;
reg [5:0] output_ptr;

reg [3:0] peg_num;
reg is_removal;
reg [DEP_WIDTH-1:0] missing_deps;
reg support_matches;

always @(*) begin
    if (dry_step[4]) begin
        peg_num = 4'd0 - dry_step[3:0];
    end else begin
        peg_num = dry_step[3:0];
    end
    is_removal = dry_step[4];
    
    case (peg_num)
        4'd0: missing_deps = current_pegs;
        4'd1: missing_deps = history_1 & ~current_pegs;
        4'd2: missing_deps = history_2 & ~current_pegs;
        4'd3: missing_deps = history_3 & ~current_pegs;
        4'd4: missing_deps = history_4 & ~current_pegs;
        default: missing_deps = current_pegs;
    endcase
    
    case (peg_num)
        4'd0: support_matches = (current_pegs == current_pegs);
        4'd1: support_matches = (current_pegs == history_1);
        4'd2: support_matches = (current_pegs == history_2);
        4'd3: support_matches = (current_pegs == history_3);
        4'd4: support_matches = (current_pegs == history_4);
        default: support_matches = 0;
    endcase
end

always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (start) next_state = LOAD_DEPS;
        end
        
        LOAD_DEPS: begin
            if (dep_valid && point_id == 0) next_state = LOAD_DRY;
            else if (dep_valid && point_id > 0) next_state = LOAD_DEPS;
        end
        
        LOAD_DRY: begin
            if (dry_valid && dry_step == 0) next_state = PROCESS;
            else if (dry_valid) next_state = LOAD_DRY;
        end
        
        PROCESS: begin
            if (dry_ptr >= dry_idx) next_state = OUTPUT;
        end
        
        OUTPUT: begin
            if (output_ptr >= wet_idx) next_state = COMPLETE;
        end
        
        COMPLETE: next_state = COMPLETE;
        
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        deps_0 <= 0;
        deps_1 <= 0;
        deps_2 <= 0;
        deps_3 <= 0;
        deps_4 <= 0;
        dry_plan_0 <= 0;
        dry_plan_1 <= 0;
        dry_plan_2 <= 0;
        dry_plan_3 <= 0;
        dry_plan_4 <= 0;
        dry_plan_5 <= 0;
        dry_plan_6 <= 0;
        dry_plan_7 <= 0;
        wet_plan_0 <= 0;
        wet_plan_1 <= 0;
        wet_plan_2 <= 0;
        wet_plan_3 <= 0;
        wet_plan_4 <= 0;
        wet_plan_5 <= 0;
        wet_plan_6 <= 0;
        wet_plan_7 <= 0;
        wet_plan_8 <= 0;
        wet_plan_9 <= 0;
        wet_plan_10 <= 0;
        wet_plan_11 <= 0;
        wet_plan_12 <= 0;
        wet_plan_13 <= 0;
        wet_plan_14 <= 0;
        wet_plan_15 <= 0;
        wet_plan_16 <= 0;
        wet_plan_17 <= 0;
        wet_plan_18 <= 0;
        wet_plan_19 <= 0;
        wet_plan_20 <= 0;
        wet_plan_21 <= 0;
        wet_plan_22 <= 0;
        wet_plan_23 <= 0;
        wet_plan_24 <= 0;
        wet_plan_25 <= 0;
        wet_plan_26 <= 0;
        wet_plan_27 <= 0;
        wet_plan_28 <= 0;
        wet_plan_29 <= 0;
        wet_plan_30 <= 0;
        wet_plan_31 <= 0;
        history_0 <= 0;
        history_1 <= 0;
        history_2 <= 0;
        history_3 <= 0;
        history_4 <= 0;
        current_pegs <= 0;
        dep_idx <= 0;
        dry_idx <= 0;
        dry_ptr <= 0;
        wet_idx <= 0;
        output_ptr <= 0;
        done <= 0;
        possible <= 1;
        wet_step <= 0;
        wet_valid <= 0;
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
        
        case (current_state)
            LOAD_DEPS: begin
                if (dep_valid && point_id > 0 && point_id <= MAX_N) begin
                    case (point_id)
                        4'd1: deps_1 <= dep_mask;
                        4'd2: deps_2 <= dep_mask;
                        4'd3: deps_3 <= dep_mask;
                        4'd4: deps_4 <= dep_mask;
                    endcase
                    dep_idx <= dep_idx + 1;
                end
                if (dep_valid && point_id == 0) begin
                    dep_idx <= 0;
                end
            end
            
            LOAD_DRY: begin
                if (dry_valid && dry_step != 0 && dry_idx < MAX_STEPS) begin
                    case (dry_idx)
                        4'd0: dry_plan_0 <= dry_step;
                        4'd1: dry_plan_1 <= dry_step;
                        4'd2: dry_plan_2 <= dry_step;
                        4'd3: dry_plan_3 <= dry_step;
                        4'd4: dry_plan_4 <= dry_step;
                        4'd5: dry_plan_5 <= dry_step;
                        4'd6: dry_plan_6 <= dry_step;
                        4'd7: dry_plan_7 <= dry_step;
                    endcase
                    dry_idx <= dry_idx + 1;
                end
                if (dry_valid && dry_step == 0) begin
                    dry_ptr <= 0;
                end
            end
            
            PROCESS: begin
                if (dry_ptr < dry_idx && wet_idx < MAX_WET_STEPS - 1) begin
                    if (!is_removal) begin
                        if (((current_pegs & deps_1) == deps_1 && peg_num == 4'd1) ||
                            ((current_pegs & deps_2) == deps_2 && peg_num == 4'd2) ||
                            ((current_pegs & deps_3) == deps_3 && peg_num == 4'd3) ||
                            ((current_pegs & deps_4) == deps_4 && peg_num == 4'd4)) begin
                            case (dry_ptr)
                                4'd0: wet_plan_wet_idx_assign = dry_plan_0;
                                4'd1: wet_plan_wet_idx_assign = dry_plan_1;
                                4'd2: wet_plan_wet_idx_assign = dry_plan_2;
                                4'd3: wet_plan_wet_idx_assign = dry_plan_3;
                                4'd4: wet_plan_wet_idx_assign = dry_plan_4;
                                4'd5: wet_plan_wet_idx_assign = dry_plan_5;
                                4'd6: wet_plan_wet_idx_assign = dry_plan_6;
                                4'd7: wet_plan_wet_idx_assign = dry_plan_7;
                            endcase
                            wet_idx <= wet_idx + 1;
                            current_pegs <= current_pegs | (1 << (peg_num - 1));
                            case (peg_num)
                                4'd1: history_1 <= current_pegs | (1 << (peg_num - 1));
                                4'd2: history_2 <= current_pegs | (1 << (peg_num - 1));
                                4'd3: history_3 <= current_pegs | (1 << (peg_num - 1));
                                4'd4: history_4 <= current_pegs | (1 << (peg_num - 1));
                            endcase
                            dry_ptr <= dry_ptr + 1;
                        end else begin
                            possible <= 0;
                            dry_ptr <= dry_idx;
                        end
                    end else begin
                        if (support_matches) begin
                            case (dry_ptr)
                                4'd0: wet_plan_wet_idx_assign = dry_plan_0;
                                4'd1: wet_plan_wet_idx_assign = dry_plan_1;
                                4'd2: wet_plan_wet_idx_assign = dry_plan_2;
                                4'd3: wet_plan_wet_idx_assign = dry_plan_3;
                                4'd4: wet_plan_wet_idx_assign = dry_plan_4;
                                4'd5: wet_plan_wet_idx_assign = dry_plan_5;
                                4'd6: wet_plan_wet_idx_assign = dry_plan_6;
                                4'd7: wet_plan_wet_idx_assign = dry_plan_7;
                            endcase
                            wet_idx <= wet_idx + 1;
                            current_pegs <= current_pegs & ~(1 << (peg_num - 1));
                            dry_ptr <= dry_ptr + 1;
                        end else if (missing_deps != 0) begin
                            if (missing_deps[0] && (deps_1 & ~current_pegs) == 0) begin
                                case (wet_idx)
                                    6'd0: wet_plan_0 <= 1;
                                    6'd1: wet_plan_1 <= 1;
                                    6'd2: wet_plan_2 <= 1;
                                    6'd3: wet_plan_3 <= 1;
                                    6'd4: wet_plan_4 <= 1;
                                    6'd5: wet_plan_5 <= 1;
                                    6'd6: wet_plan_6 <= 1;
                                    6'd7: wet_plan_7 <= 1;
                                    6'd8: wet_plan_8 <= 1;
                                    6'd9: wet_plan_9 <= 1;
                                    6'd10: wet_plan_10 <= 1;
                                    6'd11: wet_plan_11 <= 1;
                                    6'd12: wet_plan_12 <= 1;
                                    6'd13: wet_plan_13 <= 1;
                                    6'd14: wet_plan_14 <= 1;
                                    6'd15: wet_plan_15 <= 1;
                                    6'd16: wet_plan_16 <= 1;
                                    6'd17: wet_plan_17 <= 1;
                                    6'd18: wet_plan_18 <= 1;
                                    6'd19: wet_plan_19 <= 1;
                                    6'd20: wet_plan_20 <= 1;
                                    6'd21: wet_plan_21 <= 1;
                                    6'd22: wet_plan_22 <= 1;
                                    6'd23: wet_plan_23 <= 1;
                                    6'd24: wet_plan_24 <= 1;
                                    6'd25: wet_plan_25 <= 1;
                                    6'd26: wet_plan_26 <= 1;
                                    6'd27: wet_plan_27 <= 1;
                                    6'd28: wet_plan_28 <= 1;
                                    6'd29: wet_plan_29 <= 1;
                                    6'd30: wet_plan_30 <= 1;
                                    6'd31: wet_plan_31 <= 1;
                                endcase
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 0);
                                history_1 <= current_pegs | (1 << 0);
                            end else if (missing_deps[1] && (deps_2 & ~current_pegs) == 0) begin
                                case (wet_idx)
                                    6'd0: wet_plan_0 <= 2;
                                    6'd1: wet_plan_1 <= 2;
                                    6'd2: wet_plan_2 <= 2;
                                    6'd3: wet_plan_3 <= 2;
                                    6'd4: wet_plan_4 <= 2;
                                    6'd5: wet_plan_5 <= 2;
                                    6'd6: wet_plan_6 <= 2;
                                    6'd7: wet_plan_7 <= 2;
                                    6'd8: wet_plan_8 <= 2;
                                    6'd9: wet_plan_9 <= 2;
                                    6'd10: wet_plan_10 <= 2;
                                    6'd11: wet_plan_11 <= 2;
                                    6'd12: wet_plan_12 <= 2;
                                    6'd13: wet_plan_13 <= 2;
                                    6'd14: wet_plan_14 <= 2;
                                    6'd15: wet_plan_15 <= 2;
                                    6'd16: wet_plan_16 <= 2;
                                    6'd17: wet_plan_17 <= 2;
                                    6'd18: wet_plan_18 <= 2;
                                    6'd19: wet_plan_19 <= 2;
                                    6'd20: wet_plan_20 <= 2;
                                    6'd21: wet_plan_21 <= 2;
                                    6'd22: wet_plan_22 <= 2;
                                    6'd23: wet_plan_23 <= 2;
                                    6'd24: wet_plan_24 <= 2;
                                    6'd25: wet_plan_25 <= 2;
                                    6'd26: wet_plan_26 <= 2;
                                    6'd27: wet_plan_27 <= 2;
                                    6'd28: wet_plan_28 <= 2;
                                    6'd29: wet_plan_29 <= 2;
                                    6'd30: wet_plan_30 <= 2;
                                    6'd31: wet_plan_31 <= 2;
                                endcase
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 1);
                                history_2 <= current_pegs | (1 << 1);
                            end else if (missing_deps[2] && (deps_3 & ~current_pegs) == 0) begin
                                case (wet_idx)
                                    6'd0: wet_plan_0 <= 3;
                                    6'd1: wet_plan_1 <= 3;
                                    6'd2: wet_plan_2 <= 3;
                                    6'd3: wet_plan_3 <= 3;
                                    6'd4: wet_plan_4 <= 3;
                                    6'd5: wet_plan_5 <= 3;
                                    6'd6: wet_plan_6 <= 3;
                                    6'd7: wet_plan_7 <= 3;
                                    6'd8: wet_plan_8 <= 3;
                                    6'd9: wet_plan_9 <= 3;
                                    6'd10: wet_plan_10 <= 3;
                                    6'd11: wet_plan_11 <= 3;
                                    6'd12: wet_plan_12 <= 3;
                                    6'd13: wet_plan_13 <= 3;
                                    6'd14: wet_plan_14 <= 3;
                                    6'd15: wet_plan_15 <= 3;
                                    6'd16: wet_plan_16 <= 3;
                                    6'd17: wet_plan_17 <= 3;
                                    6'd18: wet_plan_18 <= 3;
                                    6'd19: wet_plan_19 <= 3;
                                    6'd20: wet_plan_20 <= 3;
                                    6'd21: wet_plan_21 <= 3;
                                    6'd22: wet_plan_22 <= 3;
                                    6'd23: wet_plan_23 <= 3;
                                    6'd24: wet_plan_24 <= 3;
                                    6'd25: wet_plan_25 <= 3;
                                    6'd26: wet_plan_26 <= 3;
                                    6'd27: wet_plan_27 <= 3;
                                    6'd28: wet_plan_28 <= 3;
                                    6'd29: wet_plan_29 <= 3;
                                    6'd30: wet_plan_30 <= 3;
                                    6'd31: wet_plan_31 <= 3;
                                endcase
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 2);
                                history_3 <= current_pegs | (1 << 2);
                            end else if (missing_deps[3] && (deps_4 & ~current_pegs) == 0) begin
                                case (wet_idx)
                                    6'd0: wet_plan_0 <= 4;
                                    6'd1: wet_plan_1 <= 4;
                                    6'd2: wet_plan_2 <= 4;
                                    6'd3: wet_plan_3 <= 4;
                                    6'd4: wet_plan_4 <= 4;
                                    6'd5: wet_plan_5 <= 4;
                                    6'd6: wet_plan_6 <= 4;
                                    6'd7: wet_plan_7 <= 4;
                                    6'd8: wet_plan_8 <= 4;
                                    6'd9: wet_plan_9 <= 4;
                                    6'd10: wet_plan_10 <= 4;
                                    6'd11: wet_plan_11 <= 4;
                                    6'd12: wet_plan_12 <= 4;
                                    6'd13: wet_plan_13 <= 4;
                                    6'd14: wet_plan_14 <= 4;
                                    6'd15: wet_plan_15 <= 4;
                                    6'd16: wet_plan_16 <= 4;
                                    6'd17: wet_plan_17 <= 4;
                                    6'd18: wet_plan_18 <= 4;
                                    6'd19: wet_plan_19 <= 4;
                                    6'd20: wet_plan_20 <= 4;
                                    6'd21: wet_plan_21 <= 4;
                                    6'd22: wet_plan_22 <= 4;
                                    6'd23: wet_plan_23 <= 4;
                                    6'd24: wet_plan_24 <= 4;
                                    6'd25: wet_plan_25 <= 4;
                                    6'd26: wet_plan_26 <= 4;
                                    6'd27: wet_plan_27 <= 4;
                                    6'd28: wet_plan_28 <= 4;
                                    6'd29: wet_plan_29 <= 4;
                                    6'd30: wet_plan_30 <= 4;
                                    6'd31: wet_plan_31 <= 4;
                                endcase
                                wet_idx <= wet_idx + 1;
                                current_pegs <= current_pegs | (1 << 3);
                                history_4 <= current_pegs | (1 << 3);
                            end else begin
                                possible <= 0;
                                dry_ptr <= dry_idx;
                            end
                        end else begin
                            possible <= 0;
                            dry_ptr <= dry_idx;
                        end
                    end
                end
            end
            
            OUTPUT: begin
                if (output_ptr < wet_idx) begin
                    case (output_ptr)
                        6'd0: wet_step <= wet_plan_0;
                        6'd1: wet_step <= wet_plan_1;
                        6'd2: wet_step <= wet_plan_2;
                        6'd3: wet_step <= wet_plan_3;
                        6'd4: wet_step <= wet_plan_4;
                        6'd5: wet_step <= wet_plan_5;
                        6'd6: wet_step <= wet_plan_6;
                        6'd7: wet_step <= wet_plan_7;
                        6'd8: wet_step <= wet_plan_8;
                        6'd9: wet_step <= wet_plan_9;
                        6'd10: wet_step <= wet_plan_10;
                        6'd11: wet_step <= wet_plan_11;
                        6'd12: wet_step <= wet_plan_12;
                        6'd13: wet_step <= wet_plan_13;
                        6'd14: wet_step <= wet_plan_14;
                        6'd15: wet_step <= wet_plan_15;
                        6'd16: wet_step <= wet_plan_16;
                        6'd17: wet_step <= wet_plan_17;
                        6'd18: wet_step <= wet_plan_18;
                        6'd19: wet_step <= wet_plan_19;
                        6'd20: wet_step <= wet_plan_20;
                        6'd21: wet_step <= wet_plan_21;
                        6'd22: wet_step <= wet_plan_22;
                        6'd23: wet_step <= wet_plan_23;
                        6'd24: wet_step <= wet_plan_24;
                        6'd25: wet_step <= wet_plan_25;
                        6'd26: wet_step <= wet_plan_26;
                        6'd27: wet_step <= wet_plan_27;
                        6'd28: wet_step <= wet_plan_28;
                        6'd29: wet_step <= wet_plan_29;
                        6'd30: wet_step <= wet_plan_30;
                        6'd31: wet_step <= wet_plan_31;
                    endcase
                    wet_valid <= 1;
                    output_ptr <= output_ptr + 1;
                end else begin
                    wet_valid <= 0;
                    done <= 1;
                end
            end
            
            COMPLETE: begin
                done <= 1;
                wet_valid <= 0;
            end
        endcase
    end
end

wire signed [DATA_WIDTH:0] wet_plan_wet_idx_assign;
always @(*) begin
    case (wet_idx)
        6'd0: wet_plan_0 = wet_plan_wet_idx_assign;
        6'd1: wet_plan_1 = wet_plan_wet_idx_assign;
        6'd2: wet_plan_2 = wet_plan_wet_idx_assign;
        6'd3: wet_plan_3 = wet_plan_wet_idx_assign;
        6'd4: wet_plan_4 = wet_plan_wet_idx_assign;
        6'd5: wet_plan_5 = wet_plan_wet_idx_assign;
        6'd6: wet_plan_6 = wet_plan_wet_idx_assign;
        6'd7: wet_plan_7 = wet_plan_wet_idx_assign;
        6'd8: wet_plan_8 = wet_plan_wet_idx_assign;
        6'd9: wet_plan_9 = wet_plan_wet_idx_assign;
        6'd10: wet_plan_10 = wet_plan_wet_idx_assign;
        6'd11: wet_plan_11 = wet_plan_wet_idx_assign;
        6'd12: wet_plan_12 = wet_plan_wet_idx_assign;
        6'd13: wet_plan_13 = wet_plan_wet_idx_assign;
        6'd14: wet_plan_14 = wet_plan_wet_idx_assign;
        6'd15: wet_plan_15 = wet_plan_wet_idx_assign;
        6'd16: wet_plan_16 = wet_plan_wet_idx_assign;
        6'd17: wet_plan_17 = wet_plan_wet_idx_assign;
        6'd18: wet_plan_18 = wet_plan_wet_idx_assign;
        6'd19: wet_plan_19 = wet_plan_wet_idx_assign;
        6'd20: wet_plan_20 = wet_plan_wet_idx_assign;
        6'd21: wet_plan_21 = wet_plan_wet_idx_assign;
        6'd22: wet_plan_22 = wet_plan_wet_idx_assign;
        6'd23: wet_plan_23 = wet_plan_wet_idx_assign;
        6'd24: wet_plan_24 = wet_plan_wet_idx_assign;
        6'd25: wet_plan_25 = wet_plan_wet_idx_assign;
        6'd26: wet_plan_26 = wet_plan_wet_idx_assign;
        6'd27: wet_plan_27 = wet_plan_wet_idx_assign;
        6'd28: wet_plan_28 = wet_plan_wet_idx_assign;
        6'd29: wet_plan_29 = wet_plan_wet_idx_assign;
        6'd30: wet_plan_30 = wet_plan_wet_idx_assign;
        6'd31: wet_plan_31 = wet_plan_wet_idx_assign;
    endcase
end

endmodule