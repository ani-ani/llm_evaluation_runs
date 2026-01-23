module fog_catcher (
    input clk,
    input rst_n,
    input start,
    input [4:0] fog_count,
    input [15:0] fog_day [0:15],
    input [7:0] fog_l [0:15],
    input [7:0] fog_r [0:15],
    input [7:0] fog_h [0:15],
    output reg [7:0] missed_count,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_FOG,
        CHECK_CONTAINMENT,
        ADD_NET,
        UPDATE_COUNTER,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] fog_index;
    reg [3:0] net_index;
    reg [3:0] net_count;
    reg [7:0] net_l [0:15];
    reg [7:0] net_r [0:15];
    reg [7:0] net_h [0:15];
    reg contained;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            fog_index <= 0;
            net_index <= 0;
            net_count <= 0;
            missed_count <= 0;
            done <= 0;
            for (int i = 0; i < 16; i = i + 1) begin
                net_l[i] <= 0;
                net_r[i] <= 0;
                net_h[i] <= 0;
            end
        end else begin
            current_state <= next_state;
            if (current_state == LOAD_FOG) begin
                fog_index <= fog_index + 1;
            end else if (current_state == CHECK_CONTAINMENT) begin
                if (net_index < net_count) begin
                    net_index <= net_index + 1;
                end else begin
                    net_index <= 0;
                end
            end else if (current_state == ADD_NET) begin
                net_count <= net_count + 1;
            end else if (current_state == UPDATE_COUNTER) begin
                missed_count <= missed_count + 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_FOG;
                end
            end
            LOAD_FOG: begin
                if (fog_index < fog_count) begin
                    next_state = CHECK_CONTAINMENT;
                end else begin
                    next_state = DONE;
                end
            end
            CHECK_CONTAINMENT: begin
                if (net_index < net_count) begin
                    next_state = CHECK_CONTAINMENT;
                end else begin
                    if (contained) begin
                        next_state = LOAD_FOG;
                    end else begin
                        next_state = ADD_NET;
                    end
                end
            end
            ADD_NET: begin
                next_state = UPDATE_COUNTER;
            end
            UPDATE_COUNTER: begin
                next_state = LOAD_FOG;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Containment check logic
    always @(*) begin
        contained = 0;
        if (current_state == CHECK_CONTAINMENT && net_index < net_count) begin
            if (fog_l[fog_index] >= net_l[net_index] &&
                fog_r[fog_index] <= net_r[net_index] &&
                fog_h[fog_index] <= net_h[net_index]) begin
                contained = 1;
            end
        end
    end

    // Add net logic
    always @(posedge clk) begin
        if (current_state == ADD_NET) begin
            net_l[net_count] <= fog_l[fog_index];
            net_r[net_count] <= fog_r[fog_index];
            net_h[net_count] <= fog_h[fog_index];
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
        end else if (current_state == DONE) begin
            done <= 1;
        end else if (current_state != DONE) begin
            done <= 0;
        end
    end

endmodule