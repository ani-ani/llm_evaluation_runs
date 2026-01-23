module PermutationShiftOptimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [3:0] n,
    output reg [15:0] min_deviation,
    output reg [3:0] best_shift,
    output reg done
);

// State definitions
localparam [1:0] IDLE = 2'd0;
localparam [1:0] LOAD = 2'd1;
localparam [1:0] COMPUTE = 2'd2;
localparam [1:0] DONE = 2'd3;

reg [1:0] state;
reg [3:0] shift_counter;
reg [3:0] element_counter;
reg [15:0] current_deviation;
reg [15:0] temp_min;
reg [3:0] temp_shift;

// Internal storage for permutation
reg [3:0] perm_0, perm_1, perm_2, perm_3, perm_4, perm_5, perm_6, perm_7;

// Combinational logic for permutation value access
reg [3:0] perm_val;
always @(*) begin
    case (element_counter)
        4'd0: perm_val = perm_0;
        4'd1: perm_val = perm_1;
        4'd2: perm_val = perm_2;
        4'd3: perm_val = perm_3;
        4'd4: perm_val = perm_4;
        4'd5: perm_val = perm_5;
        4'd6: perm_val = perm_6;
        4'd7: perm_val = perm_7;
        default: perm_val = 4'd0;
    endcase
end

// Combinational logic for target position calculation
wire [4:0] sum_pos;
wire [3:0] target_pos;
assign sum_pos = element_counter + shift_counter;
assign target_pos = (sum_pos >= n) ? (sum_pos - n) : sum_pos[3:0];

// Combinational logic for absolute difference
reg [4:0] diff;
reg [4:0] abs_diff;
always @(*) begin
    diff = perm_val - target_pos - 1'b1;
    if (diff[4]) begin
        abs_diff = ~diff + 1'b1;
    end else begin
        abs_diff = diff;
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        min_deviation <= 16'hFFFF;
        best_shift <= 4'b0;
        shift_counter <= 4'b0;
        element_counter <= 4'b0;
        current_deviation <= 16'b0;
        perm_0 <= 4'd0;
        perm_1 <= 4'd0;
        perm_2 <= 4'd0;
        perm_3 <= 4'd0;
        perm_4 <= 4'd0;
        perm_5 <= 4'd0;
        perm_6 <= 4'd0;
        perm_7 <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= LOAD;
                    shift_counter <= 4'b0;
                    element_counter <= 4'b0;
                    min_deviation <= 16'hFFFF;
                    best_shift <= 4'b0;
                end
            end
            
            LOAD: begin
                case (element_counter)
                    4'd0: perm_0 <= p_0;
                    4'd1: perm_1 <= p_1;
                    4'd2: perm_2 <= p_2;
                    4'd3: perm_3 <= p_3;
                    4'd4: perm_4 <= p_4;
                    4'd5: perm_5 <= p_5;
                    4'd6: perm_6 <= p_6;
                    4'd7: perm_7 <= p_7;
                endcase
                
                element_counter <= element_counter + 1'b1;
                if (element_counter == n - 1'b1) begin
                    state <= COMPUTE;
                    element_counter <= 4'b0;
                    current_deviation <= 16'b0;
                end
            end
            
            COMPUTE: begin
                if (element_counter < n) begin
                    current_deviation <= current_deviation + {11'b0, abs_diff[3:0]};
                    element_counter <= element_counter + 1'b1;
                end else begin
                    if (current_deviation < min_deviation) begin
                        min_deviation <= current_deviation;
                        best_shift <= shift_counter;
                    end
                    
                    shift_counter <= shift_counter + 1'b1;
                    element_counter <= 4'b0;
                    current_deviation <= 16'b0;
                    
                    if (shift_counter == n - 1'b1) begin
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
            end
            
            DONE: begin
                done <= 1'b0;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule