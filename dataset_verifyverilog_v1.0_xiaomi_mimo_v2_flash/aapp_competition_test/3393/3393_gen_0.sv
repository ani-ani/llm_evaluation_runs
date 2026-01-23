module course_selection (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  k,
    input  wire [7:0]  diff [0:7],
    input  wire [7:0]  is_level2,
    input  wire [2:0]  prereq_idx[0:7],
    output reg  [15:0] result,
    output reg         done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] INIT_MIN   = 4'd1;
    localparam [3:0] LOOP       = 4'd2;
    localparam [3:0] CHECK      = 4'd3;
    localparam [3:0] UPDATE     = 4'd4;
    localparam [3:0] INCREMENT  = 4'd5;
    localparam [3:0] DONE       = 4'd6;

    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] mask;
    reg [15:0] current_min;
    reg [15:0] temp_sum;
    reg [3:0]  temp_popcount;
    reg        temp_valid;
    reg [2:0]  i;  // Loop counter for subset evaluation
    reg [3:0]  k_reg;  // Store k value

    // State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT_MIN : IDLE;
            INIT_MIN:   next_state = LOOP;
            LOOP:       next_state = CHECK;  // One cycle to compute
            CHECK:      next_state = UPDATE;
            UPDATE:     next_state = INCREMENT;
            INCREMENT:  next_state = (mask == 8'hFF) ? DONE : LOOP;
            DONE:       next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 8'd0;
            current_min <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            temp_sum <= 16'd0;
            temp_popcount <= 4'd0;
            temp_valid <= 1'b0;
            i <= 3'd0;
            k_reg <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        k_reg <= k;
                    end
                end
                
                INIT_MIN: begin
                    current_min <= 16'hFFFF;
                    mask <= 8'd0;  // Start from first subset
                end
                
                LOOP: begin
                    // Initialize combinatorial computation
                    temp_sum <= 16'd0;
                    temp_popcount <= 4'd0;
                    temp_valid <= 1'b1;
                    i <= 3'd0;
                end
                
                CHECK: begin
                    // Continue or finish computation based on i
                    if (i < 8) begin
                        if (mask[i]) begin
                            temp_sum <= temp_sum + {8'd0, diff[i]};
                            temp_popcount <= temp_popcount + 4'd1;
                            if (is_level2[i]) begin
                                if (!mask[prereq_idx[i]]) begin
                                    temp_valid <= 1'b0;
                                end
                            end
                        end
                        i <= i + 3'd1;
                        next_state <= CHECK;  // Keep looping
                    end else begin
                        next_state <= UPDATE;
                    end
                end
                
                UPDATE: begin
                    if (temp_valid && (temp_popcount == k_reg) && (temp_sum < current_min)) begin
                        current_min <= temp_sum;
                    end
                end
                
                INCREMENT: begin
                    mask <= mask + 8'd1;
                end
                
                DONE: begin
                    result <= current_min;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule