module chocolate_division (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    output reg [15:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE        = 3'd0;
localparam [2:0] SUM         = 3'd1;
localparam [2:0] CHECK_S     = 3'd2;
localparam [2:0] FACTORIZE   = 3'd3;
localparam [2:0] COMPUTE_COST= 3'd4;
localparam [2:0] DONE_STATE  = 3'd5;

// Registers
reg [2:0] state, next_state;
reg [15:0] S;
reg [7:0] a_reg [0:7];
reg [3:0] prime_index;
reg [15:0] min_cost;
reg [15:0] current_cost;
reg [7:0] current_p;
reg [7:0] current_residue;
reg [3:0] i;
reg [15:0] temp_sum;
reg cycle_count;

// Primes up to 19 (index 0-7)
wire [7:0] next_prime;
assign next_prime = (prime_index == 4'd0) ? 8'd2 :
                    (prime_index == 4'd1) ? 8'd3 :
                    (prime_index == 4'd2) ? 8'd5 :
                    (prime_index == 4'd3) ? 8'd7 :
                    (prime_index == 4'd4) ? 8'd11 :
                    (prime_index == 4'd5) ? 8'd13 :
                    (prime_index == 4'd6) ? 8'd17 :
                    (prime_index == 4'd7) ? 8'd19 : 8'd0;

// Intermediate calculation registers
reg [7:0] remainder_temp;
reg [7:0] temp_res;
reg [7:0] new_residue;
reg [7:0] cost_element;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 16'd0;
        S <= 16'd0;
        min_cost <= 16'hFFFF;
        current_cost <= 16'd0;
        current_residue <= 8'd0;
        i <= 4'd0;
        temp_sum <= 16'd0;
        prime_index <= 4'd0;
        cycle_count <= 1'b0;
        a_reg[0] <= 8'd0;
        a_reg[1] <= 8'd0;
        a_reg[2] <= 8'd0;
        a_reg[3] <= 8'd0;
        a_reg[4] <= 8'd0;
        a_reg[5] <= 8'd0;
        a_reg[6] <= 8'd0;
        a_reg[7] <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    a_reg[0] <= arr_0;
                    a_reg[1] <= arr_1;
                    a_reg[2] <= arr_2;
                    a_reg[3] <= arr_3;
                    a_reg[4] <= arr_4;
                    a_reg[5] <= arr_5;
                    a_reg[6] <= arr_6;
                    a_reg[7] <= arr_7;
                    temp_sum <= 16'd0;
                    i <= 4'd0;
                    state <= SUM;
                end
            end
            
            SUM: begin
                if (i < n) begin
                    temp_sum <= temp_sum + a_reg[i];
                    i <= i + 4'd1;
                end else begin
                    S <= temp_sum;
                    state <= CHECK_S;
                end
            end
            
            CHECK_S: begin
                if (S == 16'd1) begin
                    result <= 16'hFFFF;
                    done <= 1'b1;
                    state <= DONE_STATE;
                end else begin
                    prime_index <= 4'd0;
                    min_cost <= 16'hFFFF;
                    state <= FACTORIZE;
                end
            end
            
            FACTORIZE: begin
                cycle_count <= cycle_count + 1'b1;
                if (prime_index <= 4'd7) begin
                    current_p <= next_prime;
                    if (next_prime != 8'd0 && (S % next_prime) == 16'd0) begin
                        current_cost <= 16'd0;
                        current_residue <= 8'd0;
                        i <= 4'd0;
                        state <= COMPUTE_COST;
                    end else begin
                        prime_index <= prime_index + 4'd1;
                    end
                end else begin
                    // Check if S is prime > 19
                    if (S > 16'd19 && 
                        (S % 16'd2 != 0) && (S % 16'd3 != 0) && (S % 16'd5 != 0) && 
                        (S % 16'd7 != 0) && (S % 16'd11 != 0) && (S % 16'd13 != 0) && 
                        (S % 16'd17 != 0) && (S % 16'd19 != 0)) begin
                        current_p <= S[7:0];
                        current_cost <= 16'd0;
                        current_residue <= 8'd0;
                        i <= 4'd0;
                        state <= COMPUTE_COST;
                    end else begin
                        result <= (min_cost == 16'hFFFF) ? 16'hFFFF : min_cost;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end
            end
            
            COMPUTE_COST: begin
                if (i < n) begin
                    // Calculate modulo and new residue
                    remainder_temp = a_reg[i] % current_p;
                    temp_res = current_residue + remainder_temp;
                    new_residue = (temp_res >= current_p) ? temp_res - current_p : temp_res;
                    
                    // Calculate element cost
                    cost_element = (new_residue <= (current_p >> 1)) ? new_residue : current_p - new_residue;
                    
                    // Update registers
                    current_cost <= current_cost + cost_element;
                    current_residue <= new_residue;
                    i <= i + 4'd1;
                end else begin
                    // Update min_cost after processing all elements
                    if (current_cost < min_cost) begin
                        min_cost <= current_cost;
                    end
                    prime_index <= prime_index + 4'd1;
                    state <= FACTORIZE;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule