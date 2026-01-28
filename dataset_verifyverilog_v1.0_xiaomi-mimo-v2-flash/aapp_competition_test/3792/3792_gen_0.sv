module fair_nut_strings (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] s,
    input wire [15:0] t,
    input wire [3:0] n,
    input wire [8:0] k,
    output reg [23:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] PROCESS   = 2'd1;
    localparam [1:0] FINISH    = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] i;              // Bit counter (0 to n-1)
    reg [9:0] count;          // Count of available strings (capped at k)
    reg [23:0] result_reg;    // Accumulated result
    reg [8:0] k_reg;          // Store k locally
    reg [3:0] n_reg;          // Store n locally
    reg [8:0] min_val;        // For min calculation
    reg [9:0] temp_count;     // Temporary for count calculation

    // Combinational logic for min operation
    always @(*) begin
        if (k_reg[8:0] < count[9:0]) begin
            min_val = k_reg[8:0];
        end else begin
            min_val = count[8:0];
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            i <= 4'd0;
            count <= 10'd0;
            result_reg <= 24'd0;
            k_reg <= 9'd0;
            n_reg <= 4'd0;
            temp_count <= 10'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        i <= 4'd0;
                        count <= 10'd1;           // Initialize count = 1
                        result_reg <= 24'd0;       // Initialize result = 0
                        k_reg <= (k > 9'd256) ? 9'd256 : k;  // Cap k at 256
                        n_reg <= n;
                    end
                end

                PROCESS: begin
                    if (i < n_reg) begin
                        // Step 1: count = count * 2
                        temp_count <= count << 1;  // Multiply by 2
                        
                        // Step 2: Check s[i] and t[i] (i-th bit)
                        // s[i] == 1 (b): subtract 1
                        // t[i] == 0 (a): subtract 1
                        // Note: We check current bit i
                        if (s[i] == 1'b1) begin
                            // s[i] == 'b', subtract 1 from temp_count
                            if (temp_count > 10'd0) begin
                                count <= temp_count - 10'd1;
                            end else begin
                                count <= 10'd0;
                            end
                        end else if (t[i] == 1'b0) begin
                            // t[i] == 'a', subtract 1 from temp_count
                            if (temp_count > 10'd0) begin
                                count <= temp_count - 10'd1;
                            end else begin
                                count <= 10'd0;
                            end
                        end else begin
                            count <= temp_count;
                        end

                        // Wait one cycle for subtraction logic to settle
                        // Use a flag to track subtraction done
                        // For simplicity, we process subtraction in next cycle
                        // Actually, let's do it all in one go with combinational logic
                        
                        // Update result (this cycle's contribution)
                        result_reg <= result_reg + min_val;

                        // Increment i
                        i <= i + 4'd1;
                    end else begin
                        // All bits processed
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule