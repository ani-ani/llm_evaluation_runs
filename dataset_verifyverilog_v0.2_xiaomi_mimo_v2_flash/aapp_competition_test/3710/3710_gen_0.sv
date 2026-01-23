module winning_strategy(
    input clk,
    input rst_n,
    input start,
    input [15:0] k,
    input [15:0] c_in,
    input valid_c,
    input done_c,
    output reg result,
    output reg output_valid
);

// States for Main FSM
localparam IDLE = 3'b000;
localparam READ_C = 3'b001;
localparam CALC_GCD1 = 3'b010;
localparam CALC_GCD2 = 3'b011;
localparam CALC_LCM = 3'b100;
localparam CHECK_DONE = 3'b101;
localparam DONE = 3'b110;

// States for GCD FSM
localparam GCD_IDLE = 1'b0;
localparam GCD_ACTIVE = 1'b1;

// Main FSM registers
reg [2:0] state;
reg [2:0] next_state;

// GCD FSM registers
reg gcd_start;
wire gcd_done;
reg [15:0] gcd_a_in;
reg [15:0] gcd_b_in;
reg [15:0] a_reg, b_reg; // Internal registers for GCD algo
wire [15:0] gcd_result;

// Data registers
reg [31:0] L;           // Accumulator L
reg [31:0] temp1;       // Holds L
reg [31:0] temp2;       // Holds G1 or G2
reg [15:0] G1_reg;      // Stores G1
reg [15:0] G2_reg;      // Stores G2
reg [15:0] c_reg;       // Stores current c_i
reg [4:0] iter_count;   // Counter for GCD iterations

// Helper signals for LCM calculation
reg [47:0] product;     // 32-bit * 16-bit max
wire [31:0] div_result;
reg div_start;
reg [4:0] div_cnt;
wire div_done;

// Division state machine for (L * G1) / G2
localparam DIV_IDLE = 1'b0;
localparam DIV_ACTIVE = 1'b1;
reg div_state;
reg [47:0] rem;         // Remainder
reg [31:0] quot;        // Quotient

assign div_done = (div_state == DIV_IDLE && div_start == 1'b0) ? 1'b1 : 
                  (div_state == DIV_ACTIVE && div_cnt == 5'd0) ? 1'b1 : 1'b0;
assign div_result = quot;

// GCD Logic
assign gcd_done = (iter_count == 5'd0);
assign gcd_result = a_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 1'b0;
        output_valid <= 1'b0;
        L <= 32'd1;
        iter_count <= 5'd0;
        a_reg <= 16'd0;
        b_reg <= 16'd0;
        gcd_start <= 1'b0;
        div_start <= 1'b0;
        div_state <= DIV_IDLE;
    end else begin
        case (state)
            IDLE: begin
                output_valid <= 1'b0;
                if (start) begin
                    L <= 32'd1;
                    state <= READ_C;
                end
            end

            READ_C: begin
                if (valid_c) begin
                    c_reg <= c_in;
                    gcd_a_in <= k;
                    gcd_b_in <= c_in;
                    // Initialize GCD registers
                    a_reg <= k;
                    b_reg <= c_in;
                    iter_count <= 5'd16;
                    gcd_start <= 1'b1;
                    state <= CALC_GCD1;
                end else if (done_c) begin
                    // Check result immediately if no numbers or after processing
                    if (L == k) result <= 1'b1;
                    else result <= 1'b0;
                    output_valid <= 1'b1;
                    state <= DONE;
                end
            end

            CALC_GCD1: begin
                gcd_start <= 1'b0;
                if (gcd_done) begin
                    G1_reg <= gcd_result;
                    // Prepare for GCD2: GCD(L, G1)
                    // Truncate L to 16 bits for GCD (GCD is defined on integers)
                    // Since L is a product of previous GCDs and k, it stays within 32 bits
                    // GCD(L, G1) calculation
                    a_reg <= L[15:0]; // Assumption: GCD arguments fit in 16 bits. 
                                       // If L > 16'hFFFF, this logic needs extension.
                                       // Based on constraints (k <= 16-bit), intermediate L usually fits.
                    b_reg <= gcd_result;
                    iter_count <= 5'd16;
                    gcd_start <= 1'b1;
                    state <= CALC_GCD2;
                end else if (iter_count > 0) begin
                    // Euclidean Algorithm Step
                    if (b_reg == 16'd0) begin
                        iter_count <= 5'd0;
                    end else begin
                        if (a_reg > b_reg) begin
                            a_reg <= a_reg - b_reg;
                        end else begin
                            b_reg <= b_reg - a_reg;
                        end
                        iter_count <= iter_count - 1'b1;
                    end
                end
            end

            CALC_GCD2: begin
                gcd_start <= 1'b0;
                if (gcd_done) begin
                    G2_reg <= gcd_result;
                    // Prepare for LCM: L = (L * G1) / G2
                    temp1 <= L;
                    temp2 <= {16'd0, G1_reg};
                    // Start Division
                    // Dividend: L * G1 (32-bit * 16-bit = 48-bit)
                    product <= L * G1_reg;
                    // Divisor: G2
                    rem <= L * G1_reg; // Init remainder
                    quot <= 32'd0;
                    div_cnt <= 5'd48; // 48 bits
                    div_state <= DIV_ACTIVE;
                    div_start <= 1'b1; // Pulse start
                    state <= CALC_LCM;
                end else if (iter_count > 0) begin
                    if (b_reg == 16'd0) begin
                        iter_count <= 5'd0;
                    end else begin
                        if (a_reg > b_reg) begin
                            a_reg <= a_reg - b_reg;
                        end else begin
                            b_reg <= b_reg - a_reg;
                        end
                        iter_count <= iter_count - 1'b1;
                    end
                end
            end

            CALC_LCM: begin
                div_start <= 1'b0;
                if (div_state == DIV_ACTIVE) begin
                    if (div_cnt > 0) begin
                        // Shift rem left, insert bit from product
                        rem <= {rem[46:0], product[47]};
                        // Shift product left
                        product <= product << 1;
                        
                        // Check condition for subtraction
                        // Compare rem[47:0] with {32'b0, G2_reg}
                        if (rem >= {32'b0, G2_reg}) begin
                            rem <= rem - {32'b0, G2_reg};
                            quot <= {quot[30:0], 1'b1};
                        end else begin
                            quot <= {quot[30:0], 1'b0};
                        end
                        
                        div_cnt <= div_cnt - 1'b1;
                    end else begin
                        // Division complete
                        div_state <= DIV_IDLE;
                        // Update L
                        L <= quot; // quot holds the result
                        // Move to next state
                        state <= CHECK_DONE;
                    end
                end
            end

            CHECK_DONE: begin
                // Check if we have more numbers
                // We stay in READ_C to catch next valid_c
                // If done_c was asserted previously, we need to handle it.
                // Actually, we need to go back to READ_C or DONE.
                // The main FSM should check if done_c is currently high or if we processed all.
                // But done_c is a pulse. We need to store it or check state.
                // We will go to READ_C. If done_c is asserted while we are in READ_C, we go to DONE.
                state <= READ_C;
            end

            DONE: begin
                if (start) begin
                    output_valid <= 1'b0;
                    L <= 32'd1;
                    state <= READ_C; // Restart
                end
            end
        endcase
    end
end

endmodule

// GCD Module implemented inside main FSM logic (Euclidean algorithm in hardware loops)
// We use the main FSM logic block for GCD calculation.

endmodule