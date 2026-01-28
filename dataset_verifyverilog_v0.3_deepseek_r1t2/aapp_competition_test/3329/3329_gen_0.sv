module pebble_counter #(
    parameter N = 6,
    parameter MAX_K = 2
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N-1:0] target,
    input wire [2:0] K,
    output reg [N-1:0] result,
    output reg done
);

// State definitions
localparam [2:0] STATE_IDLE = 3'b000;
localparam [2:0] STATE_SETUP = 3'b001;
localparam [2:0] STATE_TRANSFORM = 3'b010;
localparam [2:0] STATE_CHECK = 3'b011;
localparam [2:0] STATE_ROTATE = 3'b100;
localparam [2:0] STATE_NEXT = 3'b101;
localparam [2:0] STATE_DONE = 3'b110;

// Registers
reg [2:0] state;
reg [N-1:0] candidate;
reg [N-1:0] transformed;
reg [N-1:0] temp;
reg [2:0] k_count;
reg [2:0] rot_idx;
reg [5:0] config_counter;
reg [N-1:0] min_rot;
reg [N-1:0] temp_rot;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        result <= {N{1'b0}};
        done <= 1'b0;
        config_counter <= 6'd0;
        candidate <= {N{1'b0}};
        k_count <= 3'd0;
        transformed <= {N{1'b0}};
        min_rot <= {N{1'b0}};
        rot_idx <= 3'd0;
        temp_rot <= {N{1'b0}};
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    result <= {N{1'b0}};
                    config_counter <= 6'd0;
                    state <= STATE_SETUP;
                end
            end
            
            STATE_SETUP: begin
                candidate <= config_counter;
                transformed <= config_counter;
                k_count <= 3'd0;
                state <= STATE_TRANSFORM;
            end
            
            STATE_TRANSFORM: begin
                if (k_count < K) begin
                    temp <= transformed;
                    k_count <= k_count + 3'd1;
                end else begin
                    state <= STATE_CHECK;
                end
            end
            
            STATE_CHECK: begin
                if (transformed == target) begin
                    min_rot <= candidate;
                    rot_idx <= 3'd1;
                    state <= STATE_ROTATE;
                end else begin
                    state <= STATE_NEXT;
                end
            end
            
            STATE_ROTATE: begin
                if (rot_idx < N) begin
                    temp_rot <= {candidate[0], candidate[N-1:1]};
                    if (temp_rot < min_rot) begin
                        min_rot <= temp_rot;
                    end
                    candidate <= temp_rot;
                    rot_idx <= rot_idx + 3'd1;
                end else begin
                    candidate <= config_counter;
                    if (config_counter == min_rot) begin
                        result <= result + {{(N-1){1'b0}}, 1'b1};
                    end
                    state <= STATE_NEXT;
                end
            end
            
            STATE_NEXT: begin
                if (config_counter < (1 << N) - 1) begin
                    config_counter <= config_counter + 6'd1;
                    state <= STATE_SETUP;
                end else begin
                    state <= STATE_DONE;
                end
            end
            
            STATE_DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= STATE_IDLE;
                end
            end
            
            default: state <= STATE_IDLE;
        endcase
    end
end

// Combinational transformation logic
always @(*) begin
    if (k_count < K) begin
        transformed[N-1] = temp[N-1] ^ temp[0];
        for (integer i = 0; i < N-1; i = i + 1) begin
            transformed[i] = temp[i] ^ temp[i+1];
        end
    end
end

endmodule