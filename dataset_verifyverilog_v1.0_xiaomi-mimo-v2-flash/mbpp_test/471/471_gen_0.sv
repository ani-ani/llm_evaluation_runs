module product_mod_n (
    input clk,
    input rst_n,
    input start,
    input [15:0] arr_in,
    input valid_in,
    input [3:0] len,
    input [15:0] n,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] RECEIVE  = 3'd2;
    localparam [2:0] COMPUTE  = 3'd3;
    localparam [2:0] DIVIDE   = 3'd4;
    localparam [2:0] MULTIPLY = 3'd5;
    localparam [2:0] MOD      = 3'd6;
    localparam [2:0] DONE     = 3'd7;
    
    reg [2:0] state, next_state;
    
    // Data registers
    reg [15:0] n_reg;
    reg [15:0] len_reg;
    reg [15:0] arr_buffer [0:15];
    reg [3:0] receive_count;
    reg [3:0] process_index;
    
    // Computation registers
    reg [15:0] accumulated_product;
    reg [15:0] current_element;
    reg [15:0] temp_value;
    reg [15:0] quotient;
    reg [15:0] remainder;
    
    // Multiplication registers
    reg [31:0] mult_temp;
    reg [15:0] mult_result;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Control signals
    reg compute_element_mod;
    reg compute_product_mod;
    reg compute_mult_done;
    reg divide_done;
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            n_reg <= 16'd0;
            len_reg <= 16'd0;
            accumulated_product <= 16'd1;
            current_element <= 16'd0;
            temp_value <= 16'd0;
            quotient <= 16'd0;
            remainder <= 16'd0;
            mult_temp <= 32'd0;
            mult_result <= 16'd0;
            receive_count <= 4'd0;
            process_index <= 4'd0;
            cycle_count <= 8'd0;
            compute_element_mod <= 1'b0;
            compute_product_mod <= 1'b0;
            compute_mult_done <= 1'b0;
            divide_done <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                arr_buffer[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            // Default assignments
            done <= 1'b0;
            if (state != LOAD && state != RECEIVE && state != COMPUTE && state != DIVIDE && state != MULTIPLY && state != MOD && state != DONE) begin
                ready <= 1'b1;
            end
            
            case (state)
                IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    accumulated_product <= 16'd1;
                    receive_count <= 4'd0;
                    process_index <= 4'd0;
                    compute_element_mod <= 1'b0;
                    compute_product_mod <= 1'b0;
                    compute_mult_done <= 1'b0;
                    divide_done <= 1'b0;
                    if (start) begin
                        ready <= 1'b0;
                        n_reg <= n;
                        len_reg <= {12'd0, len};
                    end
                end
                
                LOAD: begin
                    ready <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                RECEIVE: begin
                    if (valid_in && receive_count < len_reg) begin
                        arr_buffer[receive_count] <= arr_in;
                        receive_count <= receive_count + 4'd1;
                    end
                    if (receive_count == len_reg && !valid_in) begin
                        process_index <= 4'd0;
                        accumulated_product <= 16'd1;
                    end
                end
                
                COMPUTE: begin
                    if (process_index < len_reg) begin
                        current_element <= arr_buffer[process_index];
                        temp_value <= arr_buffer[process_index];
                        quotient <= 16'd0;
                        remainder <= 16'd0;
                        divide_done <= 1'b0;
                    end
                end
                
                DIVIDE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (temp_value >= n_reg) begin
                        temp_value <= temp_value - n_reg;
                        quotient <= quotient + 16'd1;
                    end else begin
                        remainder <= temp_value;
                        divide_done <= 1'b1;
                    end
                end
                
                MULTIPLY: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (!compute_mult_done) begin
                        mult_temp <= accumulated_product * remainder;
                        compute_mult_done <= 1'b1;
                    end else begin
                        mult_result <= mult_temp[31:16];
                        temp_value <= mult_temp[31:16];
                        quotient <= 16'd0;
                        divide_done <= 1'b0;
                        compute_mult_done <= 1'b0;
                    end
                end
                
                MOD: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (temp_value >= n_reg) begin
                        temp_value <= temp_value - n_reg;
                        quotient <= quotient + 16'd1;
                    end else begin
                        accumulated_product <= temp_value;
                        process_index <= process_index + 4'd1;
                    end
                end
                
                DONE: begin
                    result <= accumulated_product;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    ready <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                next_state = RECEIVE;
            end
            
            RECEIVE: begin
                if (receive_count == len_reg && !valid_in) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = RECEIVE;
                end
            end
            
            COMPUTE: begin
                if (process_index < len_reg) begin
                    next_state = DIVIDE;
                end else begin
                    next_state = DONE;
                end
            end
            
            DIVIDE: begin
                if (divide_done) begin
                    next_state = MULTIPLY;
                end else begin
                    next_state = DIVIDE;
                end
            end
            
            MULTIPLY: begin
                if (compute_mult_done) begin
                    next_state = MOD;
                end else begin
                    next_state = MULTIPLY;
                end
            end
            
            MOD: begin
                if (temp_value < n_reg) begin
                    if (process_index < len_reg) begin
                        next_state = COMPUTE;
                    end else begin
                        next_state = DONE;
                    end
                end else begin
                    next_state = MOD;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Timeout safety
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE) begin
            next_state = DONE;
        end
    end

endmodule