module AlyonasMexicanArray (
    input clk,
    input rst_n,
    input start,
    input [7:0] n_val,
    input [7:0] m_val,
    input [7:0] l_in,
    input [7:0] r_in,
    input load_done,
    output reg [7:0] min_length,
    output reg [7:0] result_array,
    output reg done,
    output reg [5:0] addr
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] LOAD_DONE  = 3'd2;
    localparam [2:0] COMPUTE    = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] current_index;
    reg [7:0] length;
    reg [7:0] min_length_reg;
    reg [7:0] quotient;
    reg [7:0] remainder;
    reg computing_mod;
    reg [7:0] mod_counter;
    
    // For modulo operation: result = i % min_length
    // We compute: remainder = i - (quotient * min_length)
    reg [7:0] mult_temp;
    reg [7:0] sub_temp;
    
    // Cycle counter for done signal timing
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                if (load_done)
                    next_state = LOAD_DONE;
                else
                    next_state = LOAD;
            end
            
            LOAD_DONE: begin
                // Transition to compute state
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                if (current_index >= n_val[5:0] && !computing_mod)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_length <= 8'd0;
            min_length_reg <= 8'd0;
            done <= 1'b0;
            addr <= 6'd0;
            result_array <= 8'd0;
            current_index <= 6'd0;
            length <= 8'd0;
            cycle_count <= 8'd0;
            computing_mod <= 1'b0;
            mod_counter <= 8'd0;
            quotient <= 8'd0;
            remainder <= 8'd0;
            mult_temp <= 8'd0;
            sub_temp <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    // Reset outputs
                    done <= 1'b0;
                    addr <= 6'd0;
                    result_array <= 8'd0;
                    current_index <= 6'd0;
                    cycle_count <= 8'd0;
                    computing_mod <= 1'b0;
                    mod_counter <= 8'd0;
                    quotient <= 8'd0;
                    remainder <= 8'd0;
                    mult_temp <= 8'd0;
                    sub_temp <= 8'd0;
                    
                    if (start) begin
                        // Initialize min_length to max value
                        min_length <= 8'd255;
                        min_length_reg <= 8'd255;
                    end
                end
                
                LOAD: begin
                    // Update min_length based on current query
                    if (l_in <= r_in) begin
                        // Compute length = r_in - l_in + 1
                        length <= r_in - l_in + 8'd1;
                        
                        // Update min_length
                        if ((r_in - l_in + 8'd1) < min_length) begin
                            min_length <= r_in - l_in + 8'd1;
                            min_length_reg <= r_in - l_in + 8'd1;
                        end
                    end
                    
                    // Keep done low during loading
                    done <= 1'b0;
                    
                    if (load_done) begin
                        // Ensure min_length is at least 1
                        if (min_length == 8'd0 || min_length > 8'd64)
                            min_length <= 8'd1;
                        if (min_length_reg == 8'd0 || min_length_reg > 8'd64)
                            min_length_reg <= 8'd1;
                    end
                end
                
                LOAD_DONE: begin
                    // Prepare for compute phase
                    current_index <= 6'd0;
                    addr <= 6'd0;
                    computing_mod <= 1'b0;
                    mod_counter <= 8'd0;
                    quotient <= 8'd0;
                    remainder <= 8'd0;
                    mult_temp <= 8'd0;
                    sub_temp <= 8'd0;
                    cycle_count <= 8'd0;
                    done <= 1'b0;
                    result_array <= 8'd0;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (!computing_mod) begin
                        // Start computing i % min_length
                        computing_mod <= 1'b1;
                        mod_counter <= 8'd0;
                        quotient <= 8'd0;
                        remainder <= current_index[5:0];
                        mult_temp <= 8'd0;
                        sub_temp <= 8'd0;
                    end else begin
                        // Compute modulo using repeated subtraction
                        if (remainder >= min_length_reg) begin
                            remainder <= remainder - min_length_reg;
                            quotient <= quotient + 8'd1;
                        end else begin
                            // Modulo computation complete
                            result_array <= remainder;
                            addr <= current_index;
                            computing_mod <= 1'b0;
                            
                            // Move to next index
                            current_index <= current_index + 6'd1;
                        end
                    end
                    
                    // Prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    min_length <= 8'd0;
                    min_length_reg <= 8'd0;
                    done <= 1'b0;
                    addr <= 6'd0;
                    result_array <= 8'd0;
                    current_index <= 6'd0;
                    length <= 8'd0;
                    cycle_count <= 8'd0;
                    computing_mod <= 1'b0;
                    mod_counter <= 8'd0;
                    quotient <= 8'd0;
                    remainder <= 8'd0;
                    mult_temp <= 8'd0;
                    sub_temp <= 8'd0;
                end
            endcase
        end
    end

endmodule