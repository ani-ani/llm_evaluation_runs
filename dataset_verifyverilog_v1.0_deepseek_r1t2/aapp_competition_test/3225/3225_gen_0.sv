module candidate_simulation #(
    parameter N = 8,
    parameter VALUE_WIDTH = 8,
    parameter MAX_MINUTES = 16,
    parameter MINUTE_WIDTH = 5, // enough for MAX_MINUTES-1
    parameter LEN_WIDTH = 4     // enough for N
)(
    input clk,
    input rst_n,
    input start,
    input [LEN_WIDTH-1:0] len,
    input [VALUE_WIDTH-1:0] val0, val1, val2, val3, val4, val5, val6, val7,
    output reg done,
    output reg [MINUTE_WIDTH-1:0] M,
    output reg [VALUE_WIDTH-1:0] final0, final1, final2, final3, final4, final5, final6, final7,
    output reg [LEN_WIDTH-1:0] final_len
);

// State definitions
localparam [1:0] IDLE = 2'b00;
localparam [1:0] COMPUTE = 2'b01;
localparam [1:0] REMOVE = 2'b10;
localparam [1:0] DONE = 2'b11;

reg [1:0] state, next_state;

// Current values and length
reg [VALUE_WIDTH-1:0] current_values [0:N-1];
reg [LEN_WIDTH-1:0] current_len_reg;
reg [MINUTE_WIDTH-1:0] minute_count;

// Combinational leaving mask
wire [N-1:0] leaving_mask;

// Combinational logic for new values and new length
reg [VALUE_WIDTH-1:0] new_values [0:N-1];
reg [LEN_WIDTH-1:0] new_len;

// Loop integers
integer i;
integer j;

// Leaving mask computation
always @(*) begin
    for (i = 0; i < N; i = i + 1) begin
        if (i < current_len_reg) begin
            leaving_mask[i] = 1'b0;
            if (i > 0) begin
                if (current_values[i-1] > current_values[i]) begin
                    leaving_mask[i] = 1'b1;
                end
            end
            if (i < current_len_reg - 1) begin
                if (current_values[i+1] > current_values[i]) begin
                    leaving_mask[i] = 1'b1;
                end
            end
        end else begin
            leaving_mask[i] = 1'b0;
        end
    end
end

// New values and length computation
always @(*) begin
    new_len = 0;
    for (i = 0; i < N; i = i + 1) begin
        new_values[i] = 0;
    end
    
    for (i = 0; i < current_len_reg; i = i + 1) begin
        if (leaving_mask[i] == 1'b0) begin
            new_values[new_len] = current_values[i];
            new_len = new_len + 1;
        end
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        minute_count <= 5'd0;
        current_len_reg <= 4'd0;
        M <= 5'd0;
        final_len <= 4'd0;
        final0 <= 8'd0; final1 <= 8'd0; final2 <= 8'd0; final3 <= 8'd0;
        final4 <= 8'd0; final5 <= 8'd0; final6 <= 8'd0; final7 <= 8'd0;
        for (j = 0; j < N; j = j + 1) begin
            current_values[j] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    current_values[0] <= val0;
                    current_values[1] <= val1;
                    current_values[2] <= val2;
                    current_values[3] <= val3;
                    current_values[4] <= val4;
                    current_values[5] <= val5;
                    current_values[6] <= val6;
                    current_values[7] <= val7;
                    current_len_reg <= len;
                    minute_count <= 5'd0;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (leaving_mask == 8'd0 || minute_count >= MAX_MINUTES) begin
                    M <= minute_count;
                    final_len <= current_len_reg;
                    final0 <= current_values[0];
                    final1 <= current_values[1];
                    final2 <= current_values[2];
                    final3 <= current_values[3];
                    final4 <= current_values[4];
                    final5 <= current_values[5];
                    final6 <= current_values[6];
                    final7 <= current_values[7];
                    done <= 1'b1;
                    state <= DONE;
                end else begin
                    state <= REMOVE;
                end
            end
            
            REMOVE: begin
                for (j = 0; j < N; j = j + 1) begin
                    current_values[j] <= new_values[j];
                end
                current_len_reg <= new_len;
                minute_count <= minute_count + 5'd1;
                state <= COMPUTE;
            end
            
            DONE: begin
                // Stay in DONE until reset
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule