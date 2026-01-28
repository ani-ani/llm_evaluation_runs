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

reg [DEP_WIDTH-1:0] deps [0:4];
reg signed [DATA_WIDTH:0] dry_plan [0:7];
reg signed [DATA_WIDTH:0] wet_plan [0:31];
reg [DEP_WIDTH-1:0] history [0:4];
reg [DEP_WIDTH-1:0] current_pegs;

reg [3:0] dep_idx;
reg [3:0] dry_idx;
reg [3:0] dry_ptr;
reg [5:0] wet_idx;
reg [5:0] output_ptr;

wire [DEP_WIDTH-1:0] missing_deps;
wire support_matches;
wire [3:0] peg_num;
wire is_removal;

assign peg_num = dry_step[DATA_WIDTH] ? (4'd0 - dry_step[DATA_WIDTH-1:0]) : dry_step[DATA_WIDTH-1:0];
assign is_removal = dry_step[DATA_WIDTH];
assign missing_deps = history[peg_num] & ~current_pegs;
assign support_matches = (current_pegs == history[peg_num]);

always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: if (start) next_state = LOAD_DEPS;
        LOAD_DEPS: if (dep_valid && point_id == 4'd0) next_state = LOAD_DRY;
        LOAD_DRY: if (dry_valid && dry_step == 5'd0) next_state = PROCESS;
        PROCESS: if (dry_ptr >= dry_idx) next_state = OUTPUT;
        OUTPUT: if (output_ptr >= wet_idx) next_state = COMPLETE;
        COMPLETE: next_state = COMPLETE;
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        done <= 1'b0;
        possible <= 1'b1;
        wet_valid <= 1'b0;
        wet_step <= 5'sd0;
        dep_idx <= 4'd0;
        dry_idx <= 4'd0;
        dry_ptr <= 4'd0;
        wet_idx <= 6'd0;
        output_ptr <= 6'd0;
        current_pegs <= 4'b0000;
        
        deps[0] <= 4'd0; deps[1] <= 4'd0; deps[2] <= 4'd0; deps[3] <= 4'd0; deps[4] <= 4'd0;
        history[0] <= 4'd0; history[1] <= 4'd0; history[2] <= 4'd0; history[3] <= 4'd0; history[4] <= 4'd0;
        
        dry_plan[0] <= 5'sd0; dry_plan[1] <= 5'sd0; dry_plan[2] <= 5'sd0; dry_plan[3] <= 5'sd0;
        dry_plan[4] <= 5'sd0; dry_plan[5] <= 5'sd0; dry_plan[6] <= 5'sd0; dry_plan[7] <= 5'sd0;
        
        wet_plan[0] <= 5'sd0; wet_plan[1] <= 5'sd0; wet_plan[2] <= 5'sd0; wet_plan[3] <= 5'sd0;
        wet_plan[4] <= 5'sd0; wet_plan[5] <= 5'sd0; wet_plan[6] <= 5'sd0; wet_plan[7] <= 5'sd0;
        wet_plan[8] <= 5'sd0; wet_plan[9] <= 5'sd0; wet_plan[10] <= 5'sd0; wet_plan[11] <= 5'sd0;
        wet_plan[12] <= 5'sd0; wet_plan[13] <= 5'sd0; wet_plan[14] <= 5'sd0; wet_plan[15] <= 5'sd0;
        wet_plan[16] <= 5'sd0; wet_plan[17] <= 5'sd0; wet_plan[18] <= 5'sd0; wet_plan[19] <= 5'sd0;
        wet_plan[20] <= 5'sd0; wet_plan[21] <= 5'sd0; wet_plan[22] <= 5'sd0; wet_plan[23] <= 5'sd0;
        wet_plan[24] <= 5'sd0; wet_plan[25] <= 5'sd0; wet_plan[26] <= 5'sd0; wet_plan[27] <= 5'sd0;
        wet_plan[28] <= 5'sd0; wet_plan[29] <= 5'sd0; wet_plan[30] <= 5'sd0; wet_plan[31] <= 5'sd0;
    end else begin
        current_state <= next_state;
        
        case (current_state)
            IDLE: begin
                done <= 1'b0;
                possible <= 1'b1;
                wet_valid <= 1'b0;
                output_ptr <= 6'd0;
            end
            
            LOAD_DEPS: begin
                if (dep_valid && point_id != 4'd0) begin
                    deps[point_id] <= dep_mask;
                    history[point_id] <= dep_mask;
                end
            end
            
            LOAD_DRY: begin
                if (dry_valid && dry_step != 5'd0) begin
                    dry_plan[dry_idx] <= dry_step;
                    dry_idx <= dry_idx + 4'd1;
                end
            end
            
            PROCESS: begin
                if (dry_ptr < dry_idx) begin
                    if (!is_removal) begin
                        if ((current_pegs & deps[peg_num]) == deps[peg_num]) begin
                            wet_plan[wet_idx] <= dry_plan[dry_ptr];
                            wet_idx <= wet_idx + 6'd1;
                            current_pegs <= current_pegs | (4'b1 << (peg_num - 4'd1));
                            dry_ptr <= dry_ptr + 4'd1;
                        end else begin
                            possible <= 1'b0;
                            dry_ptr <= dry_idx;
                        end
                    end else begin
                        if (support_matches) begin
                            wet_plan[wet_idx] <= dry_plan[dry_ptr];
                            wet_idx <= wet_idx + 6'd1;
                            current_pegs <= current_pegs & ~(4'b1 << (peg_num - 4'd1));
                            dry_ptr <= dry_ptr + 4'd1;
                        end else begin
                            if (missing_deps[0] && (deps[4'd1] & ~current_pegs) == 4'd0) begin
                                wet_plan[wet_idx] <= 5'sd1;
                                wet_idx <= wet_idx + 6'd1;
                                current_pegs <= current_pegs | 4'b0001;
                            end else if (missing_deps[1] && (deps[4'd2] & ~current_pegs) == 4'd0) begin
                                wet_plan[wet_idx] <= 5'sd2;
                                wet_idx <= wet_idx + 6'd1;
                                current_pegs <= current_pegs | 4'b0010;
                            end else if (missing_deps[2] && (deps[4'd3] & ~current_pegs) == 4'd0) begin
                                wet_plan[wet_idx] <= 5'sd3;
                                wet_idx <= wet_idx + 6'd1;
                                current_pegs <= current_pegs | 4'b0100;
                            end else if (missing_deps[3] && (deps[4'd4] & ~current_pegs) == 4'd0) begin
                                wet_plan[wet_idx] <= 5'sd4;
                                wet_idx <= wet_idx + 6'd1;
                                current_pegs <= current_pegs | 4'b1000;
                            end else begin
                                possible <= 1'b0;
                                dry_ptr <= dry_idx;
                            end
                        end
                    end
                end
            end
            
            OUTPUT: begin
                wet_valid <= 1'b1;
                wet_step <= wet_plan[output_ptr];
                output_ptr <= output_ptr + 6'd1;
                if (output_ptr >= wet_idx - 6'd1) begin
                    done <= 1'b1;
                    wet_valid <= 1'b0;
                end
            end
            
            COMPLETE: begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule