module snake_exhibition #(
    parameter MAX_N = 16
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [MAX_N*2-1:0] belts_packed,
    output reg [4:0] count,
    output reg done
);

// State declarations
localparam [1:0] IDLE        = 2'd0;
localparam [1:0] CHECK_GT_LT = 2'd1;
localparam [1:0] COUNT_ROOMS = 2'd2;
localparam [1:0] FINISH      = 2'd3;

reg [1:0] state;
reg [1:0] next_state;
reg [3:0] i;
reg has_gt;
reg has_lt;
reg [1:0] belts [0:MAX_N-1];
reg [3:0] room_index;

// Unpack belts (combinational)
genvar g;
generate
    for (g = 0; g < MAX_N; g = g + 1) begin: unpack_belts
        always @(*) begin
            belts[g] = belts_packed[g*2 +: 2];
        end
    end
endgenerate

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE:        next_state = start ? CHECK_GT_LT : IDLE;
        CHECK_GT_LT: next_state = (i >= n) ? COUNT_ROOMS : CHECK_GT_LT;
        COUNT_ROOMS: next_state = (room_index >= n) ? FINISH : COUNT_ROOMS;
        FINISH:      next_state = IDLE;
        default:     next_state = IDLE;
    endcase
end

// Main logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        count <= 5'd0;
        has_gt <= 1'b0;
        has_lt <= 1'b0;
        i <= 4'd0;
        room_index <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                count <= 5'd0;
                i <= 4'd0;
                room_index <= 4'd0;
                if (start) begin
                    has_gt <= 1'b0;
                    has_lt <= 1'b0;
                end
            end
            
            CHECK_GT_LT: begin
                if (i < n) begin
                    if (belts[i] == 2'b01) begin
                        has_gt <= 1'b1;
                    end else if (belts[i] == 2'b10) begin
                        has_lt <= 1'b1;
                    end
                    i <= i + 4'd1;
                end
            end
            
            COUNT_ROOMS: begin
                if (room_index < n) begin
                    if (!has_gt || !has_lt) begin
                        // All rooms returnable
                        count <= {1'b0, n};
                        room_index <= n;
                    end else begin
                        // Check room returnability
                        if (room_index == 4'd0) begin // First room
                            if (belts[0] == 2'b00 || belts[n-1] == 2'b00) begin
                                count <= count + 5'd1;
                            end
                        end else begin
                            if (belts[room_index] == 2'b00 || belts[room_index-1] == 2'b00) begin
                                count <= count + 5'd1;
                            end
                        end
                        room_index <= room_index + 4'd1;
                    end
                end
            end
            
            FINISH: begin
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule