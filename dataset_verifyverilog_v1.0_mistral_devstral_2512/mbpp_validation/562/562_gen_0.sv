module max_sublist_length (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire valid_in,
    input wire end_of_sublist,
    input wire end_of_input,
    output reg [7:0] max_length,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] UPDATE_MAX = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [7:0] current_length;
    reg [7:0] max_len_reg;
    reg [2:0] sublist_count;
    reg [2:0] element_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_length <= 8'd0;
            max_len_reg <= 8'd0;
            sublist_count <= 3'd0;
            element_count <= 3'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            max_length <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (valid_in && !end_of_sublist && !end_of_input) begin
                        if (element_count < 8'd7) begin
                            element_count <= element_count + 1'b1;
                        end
                    end
                    
                    if (end_of_sublist || end_of_input) begin
                        current_length <= element_count + 1'b1;
                        element_count <= 3'd0;
                        if (end_of_sublist) begin
                            sublist_count <= sublist_count + 1'b1;
                        end
                        state <= UPDATE_MAX;
                    end
                end
                
                UPDATE_MAX: begin
                    if (current_length > max_len_reg) begin
                        max_len_reg <= current_length;
                    end
                    current_length <= 8'd0;
                    
                    if (end_of_input || sublist_count >= 8'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end else begin
                        state <= PROCESS;
                    end
                end
                
                COMPLETE: begin
                    max_length <= max_len_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule