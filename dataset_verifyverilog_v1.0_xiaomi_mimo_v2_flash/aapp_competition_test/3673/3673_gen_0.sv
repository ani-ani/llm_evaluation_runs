module arrow_permutation(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] K,
    output reg [3:0] b_0,
    output reg [3:0] b_1,
    output reg [3:0] b_2,
    output reg [3:0] b_3,
    output reg [3:0] b_4,
    output reg [3:0] b_5,
    output reg [3:0] b_6,
    output reg [3:0] b_7,
    output reg done,
    output reg impossible
);

// State declarations
localparam [2:0] IDLE         = 3'd0;
localparam [2:0] COMPUTE_GCD  = 3'd1;
localparam [2:0] CHECK_GCD    = 3'd2;
localparam [2:0] COMPUTE_INV  = 3'd3;
localparam [2:0] ASSIGN_B     = 3'd4;
localparam [2:0] DONE         = 3'd5;

// Registers
reg [2:0] state, next_state;
reg [3:0] i_cnt;              // Counter for loops (0 to N-1)
reg [3:0] gcd_a, gcd_b;       // For GCD computation
reg [3:0] gcd_temp;
reg [7:0] s_counter;          // Counter for modular inverse search (1 to N-1)
reg [3:0] s_value;            // Store found modular inverse
reg [3:0] b_reg [0:7];        // Array to store b values
reg gcd_found;                // Flag when GCD = 1
reg inv_found;                // Flag when modular inverse found
reg [2:0] loop_cnt;           // Loop counter for cycles

// Wires for modulo operation
wire [7:0] product;
wire [3:0] mod_result;

// Combinational logic for modulo: (s * K) mod N
// Since N <= 8 and K <= 255, product max is 7*255 = 1785
assign product = s_counter * K;

// Modulo by repeated subtraction (synthesizable)
assign mod_result = (product % N);  // Using % for synthesis clarity
// For pure combinational subtraction approach:
// reg [7:0] temp_mod;
// always @(*) begin
//     temp_mod = product;
//     while (temp_mod >= N) begin
//         temp_mod = temp_mod - N;
//     end
//     mod_result = temp_mod[3:0];
// end

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        // Initialize all outputs
        b_0 <= 4'd0;
        b_1 <= 4'd0;
        b_2 <= 4'd0;
        b_3 <= 4'd0;
        b_4 <= 4'd0;
        b_5 <= 4'd0;
        b_6 <= 4'd0;
        b_7 <= 4'd0;
        done <= 1'b0;
        impossible <= 1'b0;
        // Initialize internal registers
        i_cnt <= 4'd0;
        gcd_a <= 4'd0;
        gcd_b <= 4'd0;
        gcd_temp <= 4'd0;
        s_counter <= 8'd0;
        s_value <= 4'd0;
        gcd_found <= 1'b0;
        inv_found <= 1'b0;
        loop_cnt <= 3'd0;
        // Initialize b_reg array
        b_reg[0] <= 4'd0;
        b_reg[1] <= 4'd0;
        b_reg[2] <= 4'd0;
        b_reg[3] <= 4'd0;
        b_reg[4] <= 4'd0;
        b_reg[5] <= 4'd0;
        b_reg[6] <= 4'd0;
        b_reg[7] <= 4'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                i_cnt <= 4'd0;
                s_counter <= 8'd0;
                s_value <= 4'd0;
                gcd_found <= 1'b0;
                inv_found <= 1'b0;
                loop_cnt <= 3'd0;
                // Clear b_reg
                b_reg[0] <= 4'd0;
                b_reg[1] <= 4'd0;
                b_reg[2] <= 4'd0;
                b_reg[3] <= 4'd0;
                b_reg[4] <= 4'd0;
                b_reg[5] <= 4'd0;
                b_reg[6] <= 4'd0;
                b_reg[7] <= 4'd0;
            end
            
            COMPUTE_GCD: begin
                // Initialize GCD computation
                if (loop_cnt == 3'd0) begin
                    gcd_a <= N;
                    gcd_b <= K[3:0];  // Truncate to 4 bits since N <= 8
                    loop_cnt <= 3'd1;
                end else if (loop_cnt == 3'd1) begin
                    // Euclidean algorithm step
                    if (gcd_b != 4'd0) begin
                        gcd_temp <= gcd_a % gcd_b;
                        gcd_a <= gcd_b;
                        gcd_b <= gcd_temp;
                    end
                    loop_cnt <= 3'd2;
                end
            end
            
            CHECK_GCD: begin
                // Check if GCD = 1
                if (gcd_a == 4'd1 && gcd_b == 4'd0) begin
                    gcd_found <= 1'b1;
                end else begin
                    gcd_found <= 1'b0;
                    impossible <= 1'b1;
                end
                loop_cnt <= 3'd0;
            end
            
            COMPUTE_INV: begin
                // Search for modular inverse
                if (loop_cnt == 3'd0) begin
                    s_counter <= s_counter + 8'd1;
                    loop_cnt <= 3'd1;
                end else if (loop_cnt == 3'd1) begin
                    // Check if (s * K) mod N = 1
                    if (mod_result == 4'd1) begin
                        s_value <= s_counter[3:0];
                        inv_found <= 1'b1;
                        loop_cnt <= 3'd0;
                    end else begin
                        // Continue searching
                        loop_cnt <= 3'd0;
                    end
                end
            end
            
            ASSIGN_B: begin
                // Compute b_i = ((i + s) mod N) + 1
                case (i_cnt)
                    4'd0: b_reg[0] <= ((0 + s_value) % N) + 4'd1;
                    4'd1: b_reg[1] <= ((1 + s_value) % N) + 4'd1;
                    4'd2: b_reg[2] <= ((2 + s_value) % N) + 4'd1;
                    4'd3: b_reg[3] <= ((3 + s_value) % N) + 4'd1;
                    4'd4: b_reg[4] <= ((4 + s_value) % N) + 4'd1;
                    4'd5: b_reg[5] <= ((5 + s_value) % N) + 4'd1;
                    4'd6: b_reg[6] <= ((6 + s_value) % N) + 4'd1;
                    4'd7: b_reg[7] <= ((7 + s_value) % N) + 4'd1;
                endcase
                i_cnt <= i_cnt + 4'd1;
            end
            
            DONE: begin
                done <= 1'b1;
                // Update output registers
                b_0 <= b_reg[0];
                b_1 <= b_reg[1];
                b_2 <= b_reg[2];
                b_3 <= b_reg[3];
                b_4 <= b_reg[4];
                b_5 <= b_reg[5];
                b_6 <= b_reg[6];
                b_7 <= b_reg[7];
                if (impossible) begin
                    b_0 <= 4'd0;
                    b_1 <= 4'd0;
                    b_2 <= 4'd0;
                    b_3 <= 4'd0;
                    b_4 <= 4'd0;
                    b_5 <= 4'd0;
                    b_6 <= 4'd0;
                    b_7 <= 4'd0;
                end
            end
            
            default: begin
                state <= IDLE;
                done <= 1'b0;
                impossible <= 1'b0;
            end
        endcase
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) begin
                next_state = COMPUTE_GCD;
            end else begin
                next_state = IDLE;
            end
        end
        
        COMPUTE_GCD: begin
            // Run Euclidean algorithm for enough iterations
            // Max N=8, so 3-4 iterations are sufficient
            if (loop_cnt >= 3'd2 && gcd_b == 4'd0) begin
                next_state = CHECK_GCD;
            end else begin
                next_state = COMPUTE_GCD;
            end
        end
        
        CHECK_GCD: begin
            if (gcd_found) begin
                next_state = COMPUTE_INV;
            end else begin
                next_state = DONE;
            end
        end
        
        COMPUTE_INV: begin
            if (inv_found) begin
                next_state = ASSIGN_B;
            end else if (s_counter >= N && !inv_found) begin
                // Should not happen if gcd=1, but safety
                next_state = DONE;
            end else begin
                next_state = COMPUTE_INV;
            end
        end
        
        ASSIGN_B: begin
            if (i_cnt >= N) begin
                next_state = DONE;
            end else begin
                next_state = ASSIGN_B;
            end
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: begin
            next_state = IDLE;
        end
    endcase
end

endmodule