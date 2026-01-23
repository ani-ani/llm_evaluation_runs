module largest_smallest_integers (
input clk,
input rst_n, // active low
input start,
input [7:0][15:0] data_in,
output reg [31:0] largest_negative,
output reg [31:0] smallest_positive,
output reg done
);

// Internal registers
reg [31:0] largest_negative_reg;
reg [31:0] smallest_positive_reg;
reg [3:0] processing_count; // 0 to 8
reg [2:0] state;

// State definitions
localparam IDLE = 3'd0;
localparam PROCESSING = 3'd1;
localparam DONE = 3'd2;

// Default assignments (for simulation)
assign largest_negative = largest_negative_reg;
assign smallest_positive = smallest_positive_reg;
assign done = (state == DONE);

// Reset and state machine
always @(posedge clk) begin
    if (!rst_n) begin
        // Synchronous reset
        state <= IDLE;
        largest_negative_reg <= 32'd0x80000000;
        smallest_positive_reg <= 32'd0x80000000;
        processing_count <= 4'd0;
    end else begin
        case (state)
            IDLE: 
                if (start) begin
                    state <= PROCESSING;
                    processing_count <=4'd0;
                end
            PROCESSING:
                if (processing_count ==4'd0) begin
                    largest_negative_reg <=32'd0x80000000;
                    smallest_positive_reg <=32'd0x80000000;
                    processing_count <=4'd1;
                end else if (processing_count <4'd8) begin
                    integer current_val;
                    current_val = (signed)data_in[processing_count -1];
                    if (current_val <0) begin
                        if (current_val > largest_negative_reg) begin
                            largest_negative_reg <= current_val;
                        end
                    end else if (current_val >0) begin
                        if (current_val < smallest_positive_reg) begin
                            smallest_positive_reg <= current_val;
                        end
                    end
                    processing_count <= processing_count +1;
                end else begin
                    state <= DONE;
                end
            DONE: 
                if (start || !rst_n) begin
                    state <= IDLE;
                    processing_count <=4'd0;
                end
        endcase
    end
endmodule