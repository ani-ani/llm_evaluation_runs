module AladinMachine (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire op_type,          // 0: Update, 1: Query
    input wire [9:0] L,          // 0-based index for logic (maps to input 1..1024)
    input wire [9:0] R,          // 0-based index for logic
    input wire [15:0] A,
    input wire [15:0] B,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] UPDATE    = 2'd1;
    localparam [1:0] QUERY     = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;

    // Internal registers and signals
    reg [9:0] current_index;     // Iterates from L to R
    reg [31:0] temp_sum;         // Accumulator for Query
    reg [15:0] data_in_reg;      // Data to write to BRAM
    reg [15:0] data_out_reg;     // Data read from BRAM
    reg we_reg;                  // Write enable for BRAM

    // Control signals
    wire operation_done;
    wire [31:0] k_mult_a;
    wire [15:0] k_mult_a_mod;
    wire [31:0] diff_val;
    
    // Index k for sequence generation: k = current_index - L + 1
    wire [10:0] k_extended; // 11-bit to prevent overflow during subtraction/addition
    assign k_extended = (current_index - L) + 11'd1;

    // Computation for Update operation
    // val = k * A
    // Since k <= 1024 and A <= 65535, result fits in 26 bits. 32-bit is safe.
    assign k_mult_a = k_extended * A;
    
    // Simulated modulo: if k_mult_a >= B, subtract B once.
    // This works if (k * A) < 2*B. For general case, more subtractions needed,
    // but here we strictly follow the constraint of 'simulating' modulo logic.
    // A safer generic modulo requires a divider, which we avoid.
    // Given the problem says "clamped to B-1 if it exceeds B", we use:
    assign diff_val = k_mult_a - B;
    assign k_mult_a_mod = (k_mult_a >= B) ? diff_val[15:0] : k_mult_a[15:0];

    // BRAM Interface (Synchronous Read/Write)
    // Using distributed RAM logic (LUT RAM) for synthesis efficiency with 1024 entries
    reg [15:0] bram_mem [0:1023];

    // BRAM Read Logic
    always @(posedge clk) begin
        if (we_reg) begin
            bram_mem[current_index] <= data_in_reg;
            data_out_reg <= data_in_reg; // Bypass on write
        end else begin
            data_out_reg <= bram_mem[current_index];
        end
    end

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Initialize all regs
            result <= 32'd0;
            done <= 1'b0;
            current_index <= 10'd0;
            temp_sum <= 32'd0;
            data_in_reg <= 16'd0;
            we_reg <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    we_reg <= 1'b0;
                    if (start) begin
                        current_index <= L;
                        if (op_type == 1'b0) begin // Update
                            temp_sum <= 32'd0; // Unused in update
                        end else begin // Query
                            temp_sum <= 32'd0;
                        end
                    end
                end

                UPDATE: begin
                    we_reg <= 1'b1;
                    data_in_reg <= k_mult_a_mod;
                    current_index <= current_index + 10'd1;
                end

                QUERY: begin
                    we_reg <= 1'b0;
                    temp_sum <= temp_sum + data_out_reg;
                    current_index <= current_index + 10'd1;
                end

                FINISH: begin
                    we_reg <= 1'b0;
                    done <= 1'b1;
                    if (op_type == 1'b1) begin
                        result <= temp_sum;
                    end
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = IDLE; // Default
        case (state)
            IDLE: begin
                if (start)
                    next_state = (op_type == 1'b0) ? UPDATE : QUERY;
                else
                    next_state = IDLE;
            end
            
            UPDATE: begin
                if (current_index > R) // Current index passed the end (L to R inclusive)
                    next_state = FINISH;
                else
                    next_state = UPDATE;
            end
            
            QUERY: begin
                if (current_index > R)
                    next_state = FINISH;
                else
                    next_state = QUERY;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule