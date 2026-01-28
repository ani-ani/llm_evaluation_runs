module base_negk_converter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] p,
    input wire [15:0] k,
    output reg [15:0] coeff [0:31],
    output reg [5:0] len,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd32;

    // Internal signals
    reg [63:0] current;
    reg [15:0] rem;
    reg [5:0] idx;
    reg [15:0] k_reg;
    reg [63:0] p_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current <= 64'd0;
            rem <= 16'd0;
            idx <= 6'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            error <= 1'b0;
            len <= 6'd0;
            
            // Initialize coefficient array
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                coeff[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Store inputs
                        p_reg <= p;
                        k_reg <= k;
                        
                        // Initialize computation
                        current <= p_reg;
                        idx <= 6'd0;
                        
                        // Initialize coefficient array
                        integer i;
                        for (i = 0; i < 32; i = i + 1) begin
                            coeff[i] <= 16'd0;
                        end
                        
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute remainder
                    rem <= current % k_reg;
                    
                    // Adjust remainder to be non-negative
                    if (rem < 0) begin
                        rem <= rem + k_reg;
                    end
                    
                    // Store coefficient
                    coeff[idx] <= rem;
                    
                    // Update current
                    current <= -((current - rem) / k_reg);
                    
                    // Increment index
                    idx <= idx + 6'd1;
                    
                    // Check termination conditions
                    if (current == 64'd0 || cycle_count >= MAX_CYCLES) begin
                        if (current == 64'd0 && idx > 6'd0) begin
                            // Valid solution found
                            len <= idx;
                            error <= 1'b0;
                            state <= FINISH;
                        end else begin
                            // No solution or iteration limit reached
                            len <= 6'd0;
                            error <= 1'b1;
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule