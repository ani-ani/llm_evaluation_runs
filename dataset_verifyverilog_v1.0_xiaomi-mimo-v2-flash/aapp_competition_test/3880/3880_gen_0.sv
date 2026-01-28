module YaroslavProblem (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg [31:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_N     = 3'd1;
    localparam [2:0] LOAD_DATA  = 3'd2;
    localparam [2:0] CALCULATE  = 3'd3;
    localparam [2:0] OUTPUT     = 3'd4;
    localparam [2:0] WAIT_READY = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] n_reg;
    reg [4:0] total_elements;
    reg [4:0] element_counter;
    reg signed [31:0] sum_abs;
    reg signed [15:0] min_abs;
    reg [4:0] neg_count;
    reg n_odd_flag;
    reg neg_count_odd_flag;
    
    // Temporary calculation registers
    reg signed [7:0] abs_val;
    reg signed [31:0] temp_result;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'sd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            total_elements <= 5'd0;
            element_counter <= 5'd0;
            sum_abs <= 32'sd0;
            min_abs <= 16'sd127; // Max positive 8-bit is 127, min_abs will be updated
            neg_count <= 5'd0;
            n_odd_flag <= 1'b0;
            neg_count_odd_flag <= 1'b0;
            abs_val <= 8'sd0;
            temp_result <= 32'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_N;
                        n_reg <= n;
                        // Calculate 2*n - 1
                        total_elements <= (n << 1) - 5'd1;
                        // Pre-calculate parity of n
                        n_odd_flag <= n[0]; // n is odd if LSB is 1
                        // Reset accumulation registers
                        sum_abs <= 32'sd0;
                        neg_count <= 5'd0;
                        min_abs <= 16'sd255; // Initialize to max possible 8-bit unsigned (or signed 127, but 255 covers range)
                        element_counter <= 5'd0;
                    end
                end

                LOAD_N: begin
                    // Move to loading data immediately
                    state <= LOAD_DATA;
                end

                LOAD_DATA: begin
                    if (data_valid) begin
                        element_counter <= element_counter + 5'd1;
                        
                        // Calculate absolute value
                        if (data_in[7]) begin // Negative
                            abs_val <= -data_in;
                            neg_count <= neg_count + 5'd1;
                        end else begin
                            abs_val <= data_in;
                        end
                        
                        // Accumulate sum (wait one cycle for abs_val computation logic to settle conceptually, 
                        // but since it's combinational logic on data_in, we can use it directly or register it.
                        // Let's register abs_val for stability)
                        sum_abs <= sum_abs + {24'd0, (data_in[7] ? -data_in : data_in)};
                        
                        // Update min_abs
                        // Compare current abs_val with stored min_abs
                        // abs_val is 8-bit signed, but treated as unsigned magnitude 0-127
                        // min_abs is 16-bit to hold large sums, but stores magnitude
                        if (data_in[7]) begin
                            if ({8'd0, -data_in} < min_abs) begin
                                min_abs <= {8'd0, -data_in};
                            end
                        end else begin
                            if ({8'd0, data_in} < min_abs) begin
                                min_abs <= {8'd0, data_in};
                            end
                        end

                        if (element_counter == total_elements - 5'd1) begin
                            state <= CALCULATE;
                        end
                    end
                end

                CALCULATE: begin
                    // Determine neg_count parity
                    neg_count_odd_flag <= neg_count[0];
                    
                    // Logic derived:
                    // If n is odd: result = sum_abs
                    // If n is even:
                    //   If neg_count is even: result = sum_abs
                    //   If neg_count is odd: result = sum_abs - 2 * min_abs
                    
                    if (n_odd_flag) begin
                        temp_result <= sum_abs;
                    end else begin
                        if (neg_count_odd_flag) begin
                            temp_result <= sum_abs - (min_abs << 1);
                        end else begin
                            temp_result <= sum_abs;
                        end
                    end
                    
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= WAIT_READY;
                end

                WAIT_READY: begin
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule