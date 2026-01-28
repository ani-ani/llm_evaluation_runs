module divisor_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [3:0] div_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] ITERATE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] i;  // Counter from 1 to n_in
    reg [7:0] n_reg;  // Stored input
    reg [3:0] count_reg;  // Internal divisor count
    reg [7:0] iteration_count;  // Safety counter to prevent infinite loops
    localparam [7:0] MAX_ITERATIONS = 8'd255;  // Max 255 iterations for 8-bit

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 8'd0;
            n_reg <= 8'd0;
            count_reg <= 4'd0;
            div_count <= 4'd0;
            done <= 1'b0;
            iteration_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    iteration_count <= 8'd0;
                    if (start) begin
                        n_reg <= n_in;
                        i <= 8'd1;  // Start from 1
                        count_reg <= 4'd0;
                        iteration_count <= 8'd0;
                    end
                end
                
                ITERATE: begin
                    iteration_count <= iteration_count + 8'd1;
                    
                    // Check if n_reg % i == 0
                    if (n_reg % i == 8'd0 && i <= n_reg && n_reg != 8'd0) begin
                        count_reg <= count_reg + 4'd1;
                    end
                    
                    // Increment i
                    i <= i + 8'd1;
                end
                
                DONE: begin
                    done <= 1'b1;
                    div_count <= count_reg;
                    // Reset for next operation
                    i <= 8'd0;
                    count_reg <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                    i <= 8'd0;
                    n_reg <= 8'd0;
                    count_reg <= 4'd0;
                    div_count <= 4'd0;
                    done <= 1'b0;
                    iteration_count <= 8'd0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start && n_in != 8'd0) begin
                    next_state = ITERATE;
                end else if (start && n_in == 8'd0) begin
                    // Handle n=0 case - go directly to done with 0 count
                    next_state = DONE;
                end
            end
            
            ITERATE: begin
                // Check exit conditions
                if (i > n_reg || iteration_count >= MAX_ITERATIONS || n_reg == 8'd0) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule