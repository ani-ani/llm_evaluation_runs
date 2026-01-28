module longest_string(
    input clk,
    input rst_n,
    input start,
    input [7:0] strings [0:3][0:7],
    input [1:0] count,
    output reg [2:0] index,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] LENGTH_CHECK = 2'd1;
    localparam [1:0] DONE        = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    reg [2:0] current_index;
    reg [7:0] current_length;
    reg [2:0] max_index;
    reg [7:0] max_length;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            current_index <= 3'd0;
            current_length <= 8'd0;
            max_index <= 3'd0;
            max_length <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    current_index <= 3'd0;
                    current_length <= 8'd0;
                    max_index <= 3'd0;
                    max_length <= 8'd0;
                    
                    if (start) begin
                        if (count == 2'd0) begin
                            state <= DONE;
                        end else begin
                            state <= LENGTH_CHECK;
                        end
                    end
                end

                LENGTH_CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate current string length
                    if (current_index < count) begin
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (strings[current_index][i] == 8'd0) begin
                                current_length <= i;
                            end else begin
                                current_length <= 8'd8;
                            end
                        end
                        
                        // Update max if current is longer or equal with lower index
                        if (current_length > max_length || 
                            (current_length == max_length && current_index < max_index)) begin
                            max_length <= current_length;
                            max_index <= current_index;
                        end
                        
                        // Move to next string
                        current_index <= current_index + 3'd1;
                        current_length <= 8'd0;
                    end else begin
                        state <= DONE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    index <= max_index;
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule