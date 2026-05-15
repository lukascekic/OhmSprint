#ifndef __ATM90E26_H
#define __ATM90E26_H

#include "stm32f1xx_hal.h"
#include <stdint.h>

/* Status and special registers */
#define ATM_REG_SOFT_RESET   0x00
#define ATM_REG_SYS_STATUS   0x01
#define ATM_REG_FUNC_EN      0x02
#define ATM_REG_SAG_TH       0x03
#define ATM_REG_SMALL_P_MOD  0x04
#define ATM_REG_LAST_DATA    0x06
#define ATM_REG_LSB          0x08

/* Metering calibration bank (CSOne: 0x21-0x2B) */
#define ATM_REG_CAL_START    0x20
#define ATM_REG_PL_CONST_H   0x21
#define ATM_REG_PL_CONST_L   0x22
#define ATM_REG_L_GAIN       0x23
#define ATM_REG_L_PHI        0x24
#define ATM_REG_N_GAIN       0x25
#define ATM_REG_N_PHI        0x26
#define ATM_REG_P_START_TH   0x27
#define ATM_REG_P_NOL_TH     0x28
#define ATM_REG_Q_START_TH   0x29
#define ATM_REG_Q_NOL_TH     0x2A
#define ATM_REG_M_MODE       0x2B
#define ATM_REG_CS_ONE       0x2C

/* Measurement calibration bank (CSTwo: 0x31-0x3A) */
#define ATM_REG_ADJ_START    0x30
#define ATM_REG_U_GAIN       0x31
#define ATM_REG_I_GAIN_L     0x32
#define ATM_REG_I_GAIN_N     0x33
#define ATM_REG_U_OFFSET     0x34
#define ATM_REG_I_OFFSET_L   0x35
#define ATM_REG_I_OFFSET_N   0x36
#define ATM_REG_P_OFFSET_L   0x37
#define ATM_REG_Q_OFFSET_L   0x38
#define ATM_REG_P_OFFSET_N   0x39
#define ATM_REG_Q_OFFSET_N   0x3A
#define ATM_REG_CS_TWO       0x3B

/* Energy registers */
#define ATM_REG_AP_ENERGY    0x40
#define ATM_REG_AN_ENERGY    0x41
#define ATM_REG_AT_ENERGY    0x42
#define ATM_REG_RP_ENERGY    0x43
#define ATM_REG_RN_ENERGY    0x44
#define ATM_REG_RT_ENERGY    0x45
#define ATM_REG_EN_STATUS    0x46

/* L-line measurement registers */
#define ATM_REG_IRMS         0x48
#define ATM_REG_URMS         0x49
#define ATM_REG_PMEAN        0x4A
#define ATM_REG_QMEAN        0x4B
#define ATM_REG_FREQ         0x4C
#define ATM_REG_POWER_F      0x4D
#define ATM_REG_P_ANGLE      0x4E
#define ATM_REG_S_MEAN       0x4F

/* N-line measurement registers */
#define ATM_REG_IRMS_TWO     0x68
#define ATM_REG_PMEAN_TWO    0x6A
#define ATM_REG_QMEAN_TWO    0x6B
#define ATM_REG_POWER_F_TWO  0x6D
#define ATM_REG_P_ANGLE_TWO  0x6E
#define ATM_REG_S_MEAN_TWO   0x6F

/* SysStatus bits */
#define ATM_SYS_CAL_ERR      0xC000
#define ATM_SYS_ADJ_ERR      0x3000
#define ATM_SYS_SAG_WARN     0x0001

typedef enum {
    ATM_OK = 0,
    ATM_ERR_SPI,
    ATM_ERR_COMM_VERIFY,
    ATM_ERR_CS1_CHECKSUM,
    ATM_ERR_CS2_CHECKSUM,
    ATM_ERR_NOT_INIT
} ATM90E26_Status;

typedef struct {
    uint16_t plconstH;
    uint16_t plconstL;
    uint16_t lgain;
    uint16_t lphi;
    uint16_t ngain;
    uint16_t nphi;
    uint16_t pStartTh;
    uint16_t pNolTh;
    uint16_t qStartTh;
    uint16_t qNolTh;
    uint16_t mmode;
    uint16_t ugain;
    uint16_t igainL;
    uint16_t igainN;
    uint16_t uoffset;
    uint16_t ioffsetL;
    uint16_t ioffsetN;
    uint16_t poffsetL;
    uint16_t qoffsetL;
    uint16_t poffsetN;
    uint16_t qoffsetN;
} ATM90E26_CalConfig;

typedef struct {
    uint16_t voltage;       /* raw /100 = V */
    uint16_t current;       /* raw /1000 = A */
    uint16_t currentN;      /* raw /1000 = A */
    int16_t  activePower;   /* raw W */
    int16_t  reactivePower; /* raw VAR */
    uint16_t apparentPower; /* raw VA, unsigned */
    uint16_t frequency;     /* raw /100 = Hz */
    int16_t  powerFactor;   /* decoded signed, /1000 */
    int16_t  phaseAngle;    /* decoded signed, /10 deg */
    uint16_t importEnergy;  /* raw delta, 0.1 Wh */
    uint16_t exportEnergy;  /* raw delta, 0.1 Wh */
} ATM90E26_Meas;

typedef struct {
    SPI_HandleTypeDef *hspi;
    GPIO_TypeDef      *csPort;
    uint16_t           csPin;
    ATM90E26_CalConfig cal;
    uint32_t           totalImportEnergy; /* 0.1 Wh */
    uint32_t           totalExportEnergy; /* 0.1 Wh */
    uint16_t           lastSysStatus;
    uint8_t            initialized;
} ATM90E26_Dev;

ATM90E26_CalConfig ATM90E26_DefaultCal(void);

ATM90E26_Status ATM90E26_Init(ATM90E26_Dev *dev);
ATM90E26_Status ATM90E26_ReadAll(ATM90E26_Dev *dev, ATM90E26_Meas *m);

uint16_t ATM90E26_GetSysStatus(ATM90E26_Dev *dev);
uint16_t ATM90E26_GetMeterStatus(ATM90E26_Dev *dev);

uint16_t ATM90E26_ReadReg(ATM90E26_Dev *dev, uint8_t reg);
void     ATM90E26_WriteReg(ATM90E26_Dev *dev, uint8_t reg, uint16_t val);

#endif /* __ATM90E26_H */
