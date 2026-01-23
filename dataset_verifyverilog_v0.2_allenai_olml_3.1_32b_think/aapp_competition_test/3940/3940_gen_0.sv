module array_specializer (
    input clk,
    input rst_n, // active low
    input start,
    input query_valid,
    input [2:0] l_i,
    input [2:0] r_i,
    output reg [2:0] min_mex,
    output reg [2:0] array_out,
    output reg output_valid,
    output reg done
);

parameter M =4;
parameter N =8;

// Registers
reg [3:0] current_min_length; // initialized to 9
reg [2:0] query_count;
reg [2:0] state;
reg [3:0] output_counter;

// State definitions
localparam IDLE = 3'd0;
localparam READ_QUERIES = 3'd1;
localparam COMPUTE = 3'd2;
localparam OUTPUT = 3'd3;

// Initialize registers on reset
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_min_length <= 9;
        query_count <=0;
        state <= IDLE;
        output_counter <=0;
        min_mex <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= READ_QUERIES;
                end
            end
            READ_QUERIES: begin
                if (query_valid) begin
                    current_min_length <= min(current_min_length, r_i - l_i +1);
                    query_count <= query_count +1;
                    if (query_count == M) begin
                        state <= COMPUTE;
                    end
                end
            end
            COMPUTE: begin
                min_mex <= current_min_length;
                state <= OUTPUT;
            end
            OUTPUT: begin
                if (output_counter < N) begin
                    array_out <= output_counter % current_min_length;
                    output_counter <= output_counter +1;
                    output_valid <=1;
                    done <=1;
                end else begin
                    state <= IDLE;
                    output_counter <=0;
                    output_valid <=0;
                end
            end
        endcase
    end
end
endmodule