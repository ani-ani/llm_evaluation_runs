module exploding_worms (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] shoot_index,
    input wire [7:0] pos0,
    input wire [7:0] pos1,
    input wire [7:0] pos2,
    input wire [7:0] pos3,
    input wire [7:0] pos4,
    input wire [7:0] pos5,
    input wire [7:0] pos6,
    input wire [7:0] pos7,
    input wire [7:0] rad0,
    input wire [7:0] rad1,
    input wire [7:0] rad2,
    input wire [7:0] rad3,
    input wire [7:0] rad4,
    input wire [7:0] rad5,
    input wire [7:0] rad6,
    input wire [7:0] rad7,
    output reg [3:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE     = 3'd0;
localparam [2:0] INIT     = 3'd1;
localparam [2:0] EXPAND_I = 3'd2;
localparam [2:0] EXPAND_J = 3'd3;
localparam [2:0] CHECK    = 3'd4;
localparam [2:0] COUNT    = 3'd5;
localparam [2:0] DONE_S   = 3'd6;

// Internal registers
reg [2:0] state;
reg [2:0] next_state;
reg [7:0] mask;
reg [7:0] new_mask;
reg [2:0] i;
reg [2:0] j;
reg [2:0] iteration_count;

// Wire arrays for positions and radii (avoid unpacked array ports)
wire [7:0] pos [0:7];
wire [7:0] rad [0:7];

assign pos[0] = pos0;
assign pos[1] = pos1;
assign pos[2] = pos2;
assign pos[3] = pos3;
assign pos[4] = pos4;
assign pos[5] = pos5;
assign pos[6] = pos6;
assign pos[7] = pos7;

assign rad[0] = rad0;
assign rad[1] = rad1;
assign rad[2] = rad2;
assign rad[3] = rad3;
assign rad[4] = rad4;
assign rad[5] = rad5;
assign rad[6] = rad6;
assign rad[7] = rad7;

// Combinational logic for absolute difference and condition
wire signed [8:0] diff;
wire [7:0] abs_diff;
wire condition;

// Sign-extend to 9 bits for signed subtraction
assign diff = $signed({{1{pos[i][7]}}, pos[i]}) - $signed({{1{pos[j][7]}}, pos[j]});

// Absolute value calculation
assign abs_diff = diff[8] ? ((~diff[7:0]) + 8'd1) : diff[7:0];

// Condition check (only during EXPAND_J state)
assign condition = (abs_diff <= rad[i]) && (state == EXPAND_J);

// Popcount of mask (combinational)
wire [3:0] popcount;
assign popcount = mask[0] + mask[1] + mask[2] + mask[3] + mask[4] + mask[5] + mask[6] + mask[7];

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = INIT;
            else next_state = IDLE;
        end
        INIT: next_state = EXPAND_I;
        EXPAND_I: begin
            if (i >= 3'd8) next_state = CHECK;
            else if (mask[i]) next_state = EXPAND_J;
            else next_state = EXPAND_I; // stay in same state, increment i in sequential block
        end
        EXPAND_J: begin
            if (j >= 3'd8) next_state = EXPAND_I;
            else if (mask[j]) next_state = EXPAND_J; // stay in same state, increment j in sequential block
            else next_state = EXPAND_J; // stay in same state, increment j in sequential block
        end
        CHECK: begin
            if (new_mask == mask) next_state = COUNT;
            else if (iteration_count >= 3'd7) next_state = COUNT;
            else next_state = EXPAND_I;
        end
        COUNT: next_state = DONE_S;
        DONE_S: begin
            if (!start) next_state = IDLE;
            else next_state = DONE_S;
        end
        default: next_state = IDLE;
    endcase
end

// State machine and sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        mask <= 8'd0;
        new_mask <= 8'd0;
        i <= 3'd0;
        j <= 3'd0;
        iteration_count <= 3'd0;
        result <= 4'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                // i, j, iteration_count, mask, new_mask already initialized
            end
            
            INIT: begin
                mask <= 8'd0;
                new_mask <= 8'd0;
                // Set only the bit corresponding to shoot_index
                case (shoot_index)
                    3'd0: begin mask[0] <= 1'b1; new_mask[0] <= 1'b1; end
                    3'd1: begin mask[1] <= 1'b1; new_mask[1] <= 1'b1; end
                    3'd2: begin mask[2] <= 1'b1; new_mask[2] <= 1'b1; end
                    3'd3: begin mask[3] <= 1'b1; new_mask[3] <= 1'b1; end
                    3'd4: begin mask[4] <= 1'b1; new_mask[4] <= 1'b1; end
                    3'd5: begin mask[5] <= 1'b1; new_mask[5] <= 1'b1; end
                    3'd6: begin mask[6] <= 1'b1; new_mask[6] <= 1'b1; end
                    3'd7: begin mask[7] <= 1'b1; new_mask[7] <= 1'b1; end
                endcase
                iteration_count <= 3'd0;
                i <= 3'd0;
                j <= 3'd0;
            end
            
            EXPAND_I: begin
                if (next_state == EXPAND_J) begin
                    // Stay on current i, start j loop
                    j <= 3'd0;
                end else if (i < 3'd8) begin
                    i <= i + 3'd1;
                end
            end
            
            EXPAND_J: begin
                if (next_state == EXPAND_I) begin
                    // Done with current i, increment i
                    i <= i + 3'd1;
                end else if (j < 3'd8) begin
                    j <= j + 3'd1;
                    if (condition) begin
                        new_mask[j] <= 1'b1;
                    end
                end
            end
            
            CHECK: begin
                if (next_state == EXPAND_I) begin
                    mask <= new_mask;
                    iteration_count <= iteration_count + 3'd1;
                    i <= 3'd0;
                end
            end
            
            COUNT: begin
                result <= popcount;
            end
            
            DONE_S: begin
                done <= 1'b1;
            end
            
            default: begin
                // No additional actions needed for default case
            end
        endcase
    end
end

endmodule