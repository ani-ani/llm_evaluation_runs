module AlyonaMexicanArray(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_val,
    input wire [7:0] m_val,
    input wire [7:0] l_in,
    input wire [7:0] r_in,
    input wire load_done,
    output reg [7:0] min_length,
    output reg [7:0] result_array,
    output reg done,
    output reg [5:0] addr
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] current_min;
    reg [7:0] current_length;
    reg [5:0] index;
    reg [7:0] array_reg [0:63];
    reg [7:0] query_count;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            min_length <= 8'd0;
            current_min <= 8'd255;
            current_length <= 8'd0;
            index <= 6'd0;
            done <= 1'b0;
            addr <= 6'd0;
            result_array <= 8'd0;
            query_count <= 8'd0;
            
            // Initialize array
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                array_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    addr <= 6'd0;
                    if (start) begin
                        next_state <= LOAD;
                        current_min <= 8'd255;
                        query_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    if (load_done) begin
                        next_state <= COMPUTE;
                        index <= 6'd0;
                        min_length <= current_min;
                    end else begin
                        // Compute length for current query
                        if (r_in >= l_in) begin
                            current_length <= r_in - l_in + 8'd1;
                        end else begin
                            current_length <= 8'd0;
                        end
                        
                        // Update minimum length
                        if (current_length < current_min) begin
                            current_min <= current_length;
                        end
                        
                        // Increment query count
                        query_count <= query_count + 8'd1;
                        
                        // Check if all queries loaded
                        if (query_count >= m_val) begin
                            next_state <= COMPUTE;
                            index <= 6'd0;
                            min_length <= current_min;
                        end else begin
                            next_state <= LOAD;
                        end
                    end
                end

                COMPUTE: begin
                    // Compute array value: i % min_length
                    if (min_length == 8'd0) begin
                        array_reg[index] <= 8'd0;
                    end else begin
                        array_reg[index] <= index % min_length;
                    end
                    
                    // Move to next index
                    index <= index + 6'd1;
                    
                    // Check if all elements computed
                    if (index >= n_val) begin
                        next_state <= OUTPUT;
                        index <= 6'd0;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                OUTPUT: begin
                    result_array <= array_reg[index];
                    addr <= index;
                    
                    index <= index + 6'd1;
                    
                    if (index >= n_val) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule