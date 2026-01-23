module StringToTupleConverter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    input load_valid,
    output reg [7:0] char_out,
    output reg [2:0] out_index,
    output reg valid_out,
    output reg done,
    output reg [3:0] count
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Internal storage for input characters
    reg [7:0] char_memory [0:7];
    
    // Filtered characters storage
    reg [7:0] filtered_chars [0:7];
    
    // Counters and indices
    reg [2:0] load_counter;
    reg [2:0] output_counter;
    reg [2:0] filtered_count;
    
    // Load phase control
    reg load_complete;

    // State machine for loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            load_counter <= 3'd0;
            output_counter <= 3'd0;
            filtered_count <= 3'd0;
            load_complete <= 1'b0;
            char_out <= 8'd0;
            out_index <= 3'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            count <= 4'd0;
            
            // Initialize memory
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                char_memory[i] <= 8'd0;
                filtered_chars[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        load_counter <= 3'd0;
                        load_complete <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    if (load_valid) begin
                        char_memory[char_index] <= char_in;
                        load_counter <= load_counter + 3'd1;
                        
                        if (load_counter == 3'd7) begin
                            load_complete <= 1'b1;
                        end
                    end
                    
                    if (load_complete && start) begin
                        next_state <= PROCESS;
                    end else if (!start) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= LOAD;
                    end
                end
                
                PROCESS: begin
                    // Filter characters
                    integer i, j;
                    j = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (char_memory[i] != 8'd32) begin
                            filtered_chars[j] <= char_memory[i];
                            j = j + 1;
                        end
                    end
                    filtered_count <= j;
                    count <= j;
                    output_counter <= 3'd0;
                    next_state <= OUTPUT;
                end
                
                OUTPUT: begin
                    if (output_counter < filtered_count) begin
                        char_out <= filtered_chars[output_counter];
                        out_index <= output_counter;
                        valid_out <= 1'b1;
                        output_counter <= output_counter + 3'd1;
                        next_state <= OUTPUT;
                    end else begin
                        char_out <= 8'd0;
                        out_index <= 3'd0;
                        valid_out <= 1'b0;
                        done <= 1'b1;
                        next_state <= IDLE;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule