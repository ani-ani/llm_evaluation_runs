module winning_strategy (input clk, input rst_n, // active-low reset input start, input [15:0] k, input [15:0] c_in, input valid_c, input done_c, output reg result, output reg output_valid); 
// Internal registers 
reg [31:0] L; 
reg [15:0] c_in_reg; 
reg [15:0] G1, G2; 
reg [31:0] temp1, temp2; 
reg [2:0] state; // 3-bit state encoding 

// GCD1 computation registers 
reg [15:0] a_gcd1, b_gcd1; 
reg gcd1_done; 

// GCD2 computation registers 
reg [15:0] a_gcd2, b_gcd2; 
reg gcd2_done; 

// Temporary register for GCD steps 
reg [15:0] temp; 

// State definitions 
localparam IDLE = 3'b000; 
localparam INIT = 3'b001; 
localparam WAIT_C = 3'b010; 
localparam COMPUTE_GCD1 = 3'b011; 
localparam COMPUTE_GCD2 = 3'b100; 
localparam UPDATE_L = 3'b101; 
localparam CHECK_DONE = 3'b110; 
localparam DONE_STATE = 3'b111; 

initial begin 
    L <= 32'd1; 
    c_in_reg <= 16'd0; 
    G1 <= 16'd0; 
    G2 <= 16'd0; 
    temp1 <= 32'd0; 
    temp2 <= 32'd0; 
    state <= IDLE; 
    a_gcd1 <= 16'd0; 
    b_gcd1 <= 16'd0; 
    gcd1_done <= 0; 
    a_gcd2 <= 16'd0; 
    b_gcd2 <= 16'd0; 
    gcd2_done <=0; 
    temp <= 16'd0; // Initialize temp 
end 

always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
        L <= 32'd1; 
        c_in_reg <= 16'd0; 
        G1 <= 16'd0; 
        G2 <= 16'd0; 
        temp1 <= 32'd0; 
        temp2 <= 32'd0; 
        state <= IDLE; 
        a_gcd1 <= 16'd0; 
        b_gcd1 <= 16'd0; 
        gcd1_done <= 0; 
        a_gcd2 <= 16'd0; 
        b_gcd2 <= 16'd0; 
        gcd2_done <=0; 
        temp <= 16'd0; // Reset temp 
    end else begin 
        case (state) 
            IDLE: begin 
                if (start) state <= INIT; 
            end 
            INIT: begin 
                L <= 32'd1; 
                state <= WAIT_C; 
            end 
            WAIT_C: begin 
                if (valid_c) begin 
                    c_in_reg <= c_in; 
                    a_gcd1 <= k; 
                    b_gcd1 <= c_in_reg; 
                    gcd1_done <=0; 
                    state <= COMPUTE_GCD1; 
                end 
            end 
            COMPUTE_GCD1: begin 
                if (!gcd1_done) begin 
                    if (b_gcd1 == 0) begin 
                        gcd1_done <=1; 
                        G1 <= a_gcd1; 
                    end else begin 
                        temp <= b_gcd1; 
                        b_gcd1 <= a_gcd1 % b_gcd1; 
                        a_gcd1 <= temp; 
                    end 
                end 
                if (gcd1_done) begin 
                    a_gcd2 <= L; 
                    b_gcd2 <= G1; 
                    gcd2_done <=0; 
                    state <= COMPUTE_GCD2; 
                end 
            end 
            COMPUTE_GCD2: begin 
                if (!gcd2_done) begin 
                    if (b_gcd2 == 0) begin 
                        gcd2_done <=1; 
                        G2 <= a_gcd2; 
                    end else begin 
                        temp <= b_gcd2; 
                        b_gcd2 <= a_gcd2 % b_gcd2; 
                        a_gcd2 <= temp; 
                    end 
                end 
                if (gcd2_done) begin 
                    state <= UPDATE_L; 
                end 
            end 
            UPDATE_L: begin 
                temp1 <= L * G1; 
                temp2 <= temp1 / G2; 
                L <= temp2; 
                if (done_c) begin 
                    state <= CHECK_DONE; 
                end else begin 
                    state <= WAIT_C; 
                end 
            end 
            CHECK_DONE: begin 
                result <= (L == ({k, 16'd0})) ? 1'b1 : 1'b0; 
                output_valid <= 1'b1; 
                state <= DONE_STATE; 
            end 
            DONE_STATE: begin 
                // Remain in DONE_STATE 
            end 
            default: state <= IDLE; 
        endcase 
    end 
end 
endmodule