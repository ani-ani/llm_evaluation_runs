module odd_filter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire in_valid,
    input wire signed [7:0] in_arr [0:15],
    input wire [3:0] in_len,
    output reg out_valid,
    output reg [3:0] out_count,
    output reg signed [7:0] out_arr [0:15]
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] count;
    reg [3:0] in_index;
    reg [3:0] out_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            out_valid <= 1'b0;
            out_count <= 4'd0;
            count <= 4'd0;
            in_index <= 4'd0;
            out_index <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize output array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                out_arr[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && in_valid) begin
                        next_state <= PROCESS;
                        count <= 4'd0;
                        in_index <= 4'd0;
                        out_index <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current element is odd
                    if (in_arr[in_index][0] == 1'b1) begin
                        out_arr[out_index] <= in_arr[in_index];
                        out_index <= out_index + 4'd1;
                        count <= count + 4'd1;
                    end
                    
                    in_index <= in_index + 4'd1;
                    
                    // Check if processing is complete
                    if (in_index == in_len || cycle_count >= MAX_CYCLES) begin
                        out_count <= count;
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= PROCESS;
                    end
                end
                
                OUTPUT: begin
                    out_valid <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    out_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule