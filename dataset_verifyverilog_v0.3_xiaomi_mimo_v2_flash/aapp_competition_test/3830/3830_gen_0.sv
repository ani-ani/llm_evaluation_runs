module snake_exhibition #(
    parameter MAX_N = 16
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,  // actual number of rooms (2-16)
    input [MAX_N*2-1:0] belts_packed,  // packed belts: each belt = 2 bits: 00='-', 01='>', 10='<'
    output reg [4:0] count,  // number of returnable rooms
    output reg done
);

// Internal state
reg [1:0] belts [0:MAX_N-1];  // unpacked belts
reg [3:0] i;  // loop counter
reg has_gt, has_lt;
reg [MAX_N-1:0] room_returnable;

// State machine
reg [1:0] state;
localparam [1:0] IDLE = 2'b00;
localparam [1:0] CHECK_GT_LT = 2'b01;
localparam [1:0] COUNT_ROOMS = 2'b10;
localparam [1:0] FINISH = 2'b11;

// Unpack belts (combinational)
genvar g;
generate
    for (g = 0; g < MAX_N; g = g + 1) begin: unpack_belts
        always @(*) begin
            belts[g] = belts_packed[2*g+1:2*g];
        end
    end
endgenerate

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        count <= 5'd0;
        has_gt <= 1'b0;
        has_lt <= 1'b0;
        i <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                i <= 4'd0;
                if (start) begin
                    has_gt <= 1'b0;
                    has_lt <= 1'b0;
                    i <= 4'd0;
                    state <= CHECK_GT_LT;
                end
            end
            
            CHECK_GT_LT: begin
                if (i < n) begin
                    if (belts[i] == 2'b01) has_gt <= 1'b1;
                    if (belts[i] == 2'b10) has_lt <= 1'b1;
                    i <= i + 4'd1;
                end else begin
                    i <= 4'd0;
                    count <= 5'd0;
                    state <= COUNT_ROOMS;
                end
            end
            
            COUNT_ROOMS: begin
                if (i < n) begin
                    // Check if room i is returnable
                    if (!has_gt || !has_lt) begin
                        // All rooms are returnable
                        count <= n;
                        state <= FINISH;
                    end else begin
                        // Check adjacent belts
                        if (i == 4'd0) begin
                            if (belts[4'd0] == 2'b00 || belts[n-1] == 2'b00)
                                count <= count + 5'd1;
                        end else begin
                            if (belts[i] == 2'b00 || belts[i-1] == 2'b00)
                                count <= count + 5'd1;
                        end
                        i <= i + 4'd1;
                    end
                end else begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule